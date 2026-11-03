import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayUnion,
  doc,
  getDoc,
  setDoc,
  updateDoc,
  writeBatch,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-recipes',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});

after(() => env.cleanup());

async function reset() {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'households/h1'), {
      name: 'Zuhause',
      memberIds: ['alice'],
      inviteCode: 'ABC234',
    });
    await setDoc(doc(db, 'invites/ABC234'), { householdId: 'h1' });
    await setDoc(doc(db, 'households/h1/recipes/r1'), { title: 'Schmarrn' });
  });
}

const as = (uid) => env.authenticatedContext(uid).firestore();

describe('households', () => {
  beforeEach(reset);

  test('member reads and writes household data', async () => {
    const db = as('alice');
    await assertSucceeds(getDoc(doc(db, 'households/h1')));
    await assertSucceeds(getDoc(doc(db, 'households/h1/recipes/r1')));
    await assertSucceeds(setDoc(doc(db, 'households/h1/pantry/mehl'), { amount: 1 }));
  });

  test('stranger cannot read or write', async () => {
    const db = as('mallory');
    await assertFails(getDoc(doc(db, 'households/h1')));
    await assertFails(getDoc(doc(db, 'households/h1/recipes/r1')));
    await assertFails(setDoc(doc(db, 'households/h1/pantry/mehl'), { amount: 1 }));
  });

  test('signed out cannot read', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'households/h1/recipes/r1')));
  });

  test('create household with seed in one batch', async () => {
    const db = as('bob');
    const batch = writeBatch(db);
    batch.set(doc(db, 'households/h2'), {
      name: 'Bob',
      memberIds: ['bob'],
      inviteCode: 'XYZ789',
    });
    batch.set(doc(db, 'invites/XYZ789'), { householdId: 'h2' });
    batch.set(doc(db, 'households/h2/ingredients/salz'), { name: 'Salz' });
    batch.set(doc(db, 'users/bob'), { householdIds: ['h2'] }, { merge: true });
    await assertSucceeds(batch.commit());
  });

  test('cannot create household for someone else', async () => {
    const db = as('bob');
    await assertFails(
      setDoc(doc(db, 'households/h3'), { name: 'x', memberIds: ['alice'], inviteCode: 'Q' }),
    );
  });

  test('cannot hijack an invite code of another household', async () => {
    const db = as('bob');
    await assertFails(setDoc(doc(db, 'invites/ABC234'), { householdId: 'h9' }));
  });
});

describe('joining', () => {
  beforeEach(reset);

  test('join with the right code', async () => {
    const db = as('bob');
    await assertSucceeds(getDoc(doc(db, 'invites/ABC234')));
    await assertSucceeds(
      updateDoc(doc(db, 'households/h1'), {
        memberIds: arrayUnion('bob'),
        joinCode: 'ABC234',
      }),
    );
    await assertSucceeds(getDoc(doc(db, 'households/h1/recipes/r1')));
  });

  test('join with a wrong code fails', async () => {
    const db = as('bob');
    await assertFails(
      updateDoc(doc(db, 'households/h1'), {
        memberIds: arrayUnion('bob'),
        joinCode: 'WRONG1',
      }),
    );
  });

  test('joiner cannot add others or change other fields', async () => {
    const db = as('bob');
    await assertFails(
      updateDoc(doc(db, 'households/h1'), {
        memberIds: arrayUnion('bob', 'eve'),
        joinCode: 'ABC234',
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'households/h1'), {
        memberIds: arrayUnion('bob'),
        joinCode: 'ABC234',
        name: 'Mine',
      }),
    );
  });
});

describe('users', () => {
  beforeEach(reset);

  test('only own user doc', async () => {
    await assertSucceeds(setDoc(doc(as('bob'), 'users/bob'), { displayName: 'Bob' }));
    await assertFails(getDoc(doc(as('bob'), 'users/alice')));
  });
});
