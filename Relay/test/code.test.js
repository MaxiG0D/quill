import assert from "node:assert/strict";
import { test } from "node:test";
import { display, signInCode } from "../src/code.js";

const found = [
  ["Your verification code is 482913", "482913"],
  ["482 913 is your Quill code", "482913"],
  ["Use 1234 as your one-time passcode", "1234"],
  ["Login code: 48291356. Do not share it.", "48291356"],
  ["Security code 482-913 expires in 10 minutes", "482913"],
  ["Your code is 2024", null],
  ["Order number 482913 has shipped", null],
  ["Invoice #482913 is due. Pay your account within 30 days", null],
  ["Total $482913 charged to your card", null],
  ["Call 555-1234 to verify your visit", null],
  ["Your package arrives 2024-11-17", null],
  ["Welcome to Quill", null],
  ["Purchase receipt. Authorization code: CU4WAS. OPUS card 329 323 7775. Payment via Apple Pay #### #### #### 7550", null],
  ["Code de vérification : 482913", "482913"],
  ["Votre code de sécurité est 4829 1356", "48291356"],
  ["Your tracking number is 123456789012 and your code is 5521", "5521"],
];

for (const [text, expected] of found) {
  test(`code in "${text}"`, () => assert.equal(signInCode(text), expected));
}

test("codes are shown in readable groups", () => {
  assert.equal(display("482913"), "482 913");
  assert.equal(display("48291356"), "4829 1356");
  assert.equal(display("1234"), "1234");
});
