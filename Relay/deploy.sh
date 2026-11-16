#!/usr/bin/env bash
# Deploys Quill's push relay to Google Cloud Run and connects Gmail to it through Pub/Sub.
# Safe to run again: every step updates what is already there.
#
#   Relay/deploy.sh ~/Developer/quill-secrets/AuthKey_ABC123DEFG.p8
#
# Needs gcloud, signed in to an account that owns the project, and billing on the project.
set -euo pipefail

PROJECT="${PROJECT:-quill-514914}"
REGION="${REGION:-northamerica-northeast1}"
TEAM_ID="${TEAM_ID:-NZN9M2VV5J}"
BUNDLE_ID="com.maxig0d.quill"
SERVICE="quill-relay"
TOPIC="gmail"
SUBSCRIPTION="gmail-relay"
SECRET="apns-key"
AUDIENCE="quill-relay"

KEY_FILE="${1:?Pass the path to the push key, AuthKey_<key ID>.p8}"
KEY_ID="${KEY_ID:-$(basename "$KEY_FILE" .p8 | sed 's/^AuthKey_//')}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLIENT_ID="$(sed -n 's/.*googleClientID = "\(.*\)".*/\1/p' "$ROOT/App/Configuration.swift")"
[ -n "$CLIENT_ID" ] || { echo "No Google client ID in App/Configuration.swift" >&2; exit 1; }

RELAY_ACCOUNT="$SERVICE@$PROJECT.iam.gserviceaccount.com"
PUBSUB_ACCOUNT="quill-pubsub@$PROJECT.iam.gserviceaccount.com"
g() { gcloud --project "$PROJECT" --quiet "$@"; }

g services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com \
  pubsub.googleapis.com firestore.googleapis.com secretmanager.googleapis.com gmail.googleapis.com

# Where the relay keeps each account's devices and place in the mailbox's history.
g firestore databases describe --database="(default)" > /dev/null 2>&1 \
  || g firestore databases create --database="(default)" --location=nam5

g secrets describe "$SECRET" > /dev/null 2>&1 || g secrets create "$SECRET" --replication-policy=automatic
g secrets versions add "$SECRET" --data-file="$KEY_FILE" > /dev/null

for account in "$SERVICE" quill-pubsub; do
  g iam service-accounts describe "$account@$PROJECT.iam.gserviceaccount.com" > /dev/null 2>&1 \
    || g iam service-accounts create "$account"
done
g projects add-iam-policy-binding "$PROJECT" --member="serviceAccount:$RELAY_ACCOUNT" \
  --role=roles/datastore.user --condition=None > /dev/null
g secrets add-iam-policy-binding "$SECRET" --member="serviceAccount:$RELAY_ACCOUNT" \
  --role=roles/secretmanager.secretAccessor > /dev/null

# Gmail publishes mailbox changes to the topic as this Google-owned account.
g pubsub topics describe "$TOPIC" > /dev/null 2>&1 || g pubsub topics create "$TOPIC"
g pubsub topics add-iam-policy-binding "$TOPIC" \
  --member="serviceAccount:gmail-api-push@system.gserviceaccount.com" --role=roles/pubsub.publisher > /dev/null

# One instance at a time keeps each account's deliveries in order.
g run deploy "$SERVICE" --source "$ROOT/Relay" --region "$REGION" --allow-unauthenticated \
  --service-account "$RELAY_ACCOUNT" --max-instances=1 --memory=256Mi \
  --set-secrets "APNS_KEY=$SECRET:latest" \
  --set-env-vars "GOOGLE_CLIENT_ID=$CLIENT_ID,GMAIL_TOPIC=projects/$PROJECT/topics/$TOPIC,PUBSUB_SERVICE_ACCOUNT=$PUBSUB_ACCOUNT,PUBSUB_AUDIENCE=$AUDIENCE,APNS_KEY_ID=$KEY_ID,APNS_TEAM_ID=$TEAM_ID,APNS_TOPIC=$BUNDLE_ID"
URL="$(g run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"

# Pub/Sub signs each delivery as quill-pubsub, which the relay checks.
NUMBER="$(g projects describe "$PROJECT" --format='value(projectNumber)')"
g iam service-accounts add-iam-policy-binding "$PUBSUB_ACCOUNT" \
  --member="serviceAccount:service-$NUMBER@gcp-sa-pubsub.iam.gserviceaccount.com" \
  --role=roles/iam.serviceAccountTokenCreator > /dev/null
PUSH=(--push-endpoint="$URL/gmail" --push-auth-service-account="$PUBSUB_ACCOUNT" --push-auth-token-audience="$AUDIENCE"
  --ack-deadline=60 --message-retention-duration=1h --expiration-period=never)
if g pubsub subscriptions describe "$SUBSCRIPTION" > /dev/null 2>&1; then
  g pubsub subscriptions update "$SUBSCRIPTION" "${PUSH[@]}"
else
  g pubsub subscriptions create "$SUBSCRIPTION" --topic "$TOPIC" "${PUSH[@]}"
fi

echo
echo "Relay is live. Set pushRelayURL in App/Configuration.swift to:"
echo "$URL"
