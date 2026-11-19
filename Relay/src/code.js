// Finding a sign-in or verification code in a message. QuillKit's `SignInCode` follows the
// same rules, and both are checked against the same examples.

const keyword =
  /\b(?:code|passcode|pass code|otp|one[- ]time|verification|v[ée]rif\w*|verify|s[ée]curit[ée]|security|confirmation|log[- ]?in|sign[- ]?in|connexion|2fa|two[- ]factor|authenticat\w*|authentification|pin)\b/i;
const candidate = /(?<![\w$#£€.,/-])(?<!\d[ -])(\d{3}[ -]\d{3}|\d{4}[ -]\d{4}|\d{4,8})(?![\w%]|[.,]\d|[ -]\d{3,4}\b)/g;
// Card, receipt and payment wording: a number beside it is not a sign-in code.
const receipt = /\b(?:receipts?|cards?|transactions?|orders?|invoices?|payments?|purchases?|factures?|re[cç]us?|achats?|cartes?|commandes?|paiements?)\b/i;
const notACode = /\b(?:order|invoice|tracking|ticket|case|account|reference|ref|phone|call|amount|total|receipt|zip)\s*(?:no\.?|number|#)?\W*$/i;

/** The digits of the first sign-in code in the text, or null when there is none. */
export function signInCode(text) {
  for (const match of text.matchAll(candidate)) {
    const digits = match[1].replace(/\D/g, "");
    if (digits.length === 4 && /^(19|20)\d\d$/.test(digits)) continue;
    const before = text.slice(Math.max(0, match.index - 60), match.index);
    const after = text.slice(match.index + match[0].length, match.index + match[0].length + 25);
    if (notACode.test(before.slice(-24))) continue;
    if (receipt.test(before.slice(-40)) || receipt.test(after.slice(0, 20))) continue;
    if (keyword.test(before) || keyword.test(after)) return digits;
  }
  return null;
}

/** A code as it is shown, in groups that are easy to read: 482913 becomes "482 913". */
export function display(digits) {
  if (digits.length === 6) return `${digits.slice(0, 3)} ${digits.slice(3)}`;
  if (digits.length === 8) return `${digits.slice(0, 4)} ${digits.slice(4)}`;
  return digits;
}
