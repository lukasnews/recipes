import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, setDoc } from 'firebase/firestore';
import { deleteObject, getBytes, ref, uploadBytes } from 'firebase/storage';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-recipes',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
    storage: { rules: readFileSync('../storage.rules', 'utf8') },
  });
});

after(() => env.cleanup());

const photo = 'households/h1/recipes/r1/1.jpg';
const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);

async function reset() {
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'households/h1'), {
      name: 'Zuhause',
      memberIds: ['alice'],
      inviteCode: 'ABC234',
    });
    await uploadBytes(ref(ctx.storage(), photo), jpeg, { contentType: 'image/jpeg' });
  });
}

const storageAs = (uid) => env.authenticatedContext(uid).storage();

describe('storage', () => {
  beforeEach(reset);

  test('member uploads, reads and deletes photos', async () => {
    const s = storageAs('alice');
    await assertSucceeds(
      uploadBytes(ref(s, 'households/h1/recipes/r1/2.jpg'), jpeg, { contentType: 'image/jpeg' }),
    );
    await assertSucceeds(getBytes(ref(s, photo)));
    await assertSucceeds(deleteObject(ref(s, photo)));
  });

  test('stranger can do nothing', async () => {
    const s = storageAs('mallory');
    await assertFails(getBytes(ref(s, photo)));
    await assertFails(
      uploadBytes(ref(s, 'households/h1/recipes/r1/3.jpg'), jpeg, { contentType: 'image/jpeg' }),
    );
    await assertFails(deleteObject(ref(s, photo)));
  });

  test('only images are accepted', async () => {
    const s = storageAs('alice');
    await assertFails(
      uploadBytes(ref(s, 'households/h1/x.txt'), new Uint8Array([1]), { contentType: 'text/plain' }),
    );
  });

  test('files above 5 MB are rejected', async () => {
    const s = storageAs('alice');
    await assertFails(
      uploadBytes(ref(s, 'households/h1/big.jpg'), new Uint8Array(5 * 1024 * 1024 + 1), {
        contentType: 'image/jpeg',
      }),
    );
  });
});
