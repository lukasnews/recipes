import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  arrayRemove,
  arrayUnion,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  Timestamp,
  where,
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

describe('members', () => {
  beforeEach(reset);

  test('own allergies: write own, read all, not others', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(doc(ctx.firestore(), 'households/h1'), { memberIds: ['alice', 'bob'] });
    });
    const alice = as('alice');
    const bob = as('bob');
    await assertSucceeds(setDoc(doc(alice, 'households/h1/members/alice'), { allergens: ['gluten'] }));
    await assertSucceeds(getDoc(doc(bob, 'households/h1/members/alice')));
    await assertFails(setDoc(doc(bob, 'households/h1/members/alice'), { allergens: [] }));
    await assertFails(setDoc(doc(as('mallory'), 'households/h1/members/mallory'), { allergens: [] }));
  });
});

describe('users', () => {
  beforeEach(reset);

  test('only own user doc', async () => {
    await assertSucceeds(setDoc(doc(as('bob'), 'users/bob'), { displayName: 'Bob' }));
    await assertFails(getDoc(doc(as('bob'), 'users/alice')));
  });
});

describe('deleting the account', () => {
  beforeEach(reset);

  test('last member deletes data, invite and household', async () => {
    const db = as('alice');
    await assertSucceeds(deleteDoc(doc(db, 'households/h1/recipes/r1')));
    await assertSucceeds(deleteDoc(doc(db, 'invites/ABC234')));
    await assertSucceeds(deleteDoc(doc(db, 'households/h1')));
  });

  test('stranger cannot delete a household', async () => {
    await assertFails(deleteDoc(doc(as('mallory'), 'households/h1')));
  });

  test('a household with other members cannot be deleted, only left', async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await updateDoc(doc(db, 'households/h1'), { memberIds: ['alice', 'bob'] });
      await setDoc(doc(db, 'households/h1/members/bob'), { displayName: 'Bob' });
    });
    const db = as('bob');
    await assertFails(deleteDoc(doc(db, 'households/h1')));
    await assertSucceeds(deleteDoc(doc(db, 'households/h1/members/bob')));
    await assertSucceeds(
      updateDoc(doc(db, 'households/h1'), { memberIds: arrayRemove('bob') }),
    );
    await assertFails(getDoc(doc(db, 'households/h1/recipes/r1')));
  });
});

describe('invite code', () => {
  beforeEach(reset);

  test('member renews the code: old invite gone, new one points here', async () => {
    const db = as('alice');
    const batch = writeBatch(db);
    batch.update(doc(db, 'households/h1'), { inviteCode: 'NEW234' });
    batch.set(doc(db, 'invites/NEW234'), { householdId: 'h1' });
    batch.delete(doc(db, 'invites/ABC234'));
    await assertSucceeds(batch.commit());
  });

  test('stranger cannot renew or delete the code', async () => {
    const db = as('mallory');
    await assertFails(deleteDoc(doc(db, 'invites/ABC234')));
    const batch = writeBatch(db);
    batch.update(doc(db, 'households/h1'), { inviteCode: 'BAD234' });
    batch.set(doc(db, 'invites/BAD234'), { householdId: 'h1' });
    await assertFails(batch.commit());
  });
});

describe('shared recipes', () => {
  beforeEach(reset);

  const recipe = (uid, extra = {}) => ({
    title: 'Kaiserschmarrn',
    createdBy: uid,
    senderName: 'Alice',
    ...extra,
  });

  test('sender creates, anyone with the code reads, only sender deletes', async () => {
    await assertSucceeds(setDoc(doc(as('alice'), 'sharedRecipes/K7MQX4PA'), recipe('alice')));
    await assertSucceeds(getDoc(doc(as('bob'), 'sharedRecipes/K7MQX4PA')));
    await assertSucceeds(
      getDoc(doc(env.unauthenticatedContext().firestore(), 'sharedRecipes/K7MQX4PA')),
    );
    await assertFails(updateDoc(doc(as('bob'), 'sharedRecipes/K7MQX4PA'), { title: 'X' }));
    await assertFails(deleteDoc(doc(as('bob'), 'sharedRecipes/K7MQX4PA')));
    await assertSucceeds(updateDoc(doc(as('alice'), 'sharedRecipes/K7MQX4PA'), { photoPath: 'p' }));
    await assertSucceeds(deleteDoc(doc(as('alice'), 'sharedRecipes/K7MQX4PA')));
  });

  test('no creating in someone else\'s name, no odd codes, no logged-out writes', async () => {
    await assertFails(setDoc(doc(as('mallory'), 'sharedRecipes/K7MQX4PA'), recipe('alice')));
    await assertFails(setDoc(doc(as('alice'), 'sharedRecipes/SHORT'), recipe('alice')));
    await assertFails(
      setDoc(doc(env.unauthenticatedContext().firestore(), 'sharedRecipes/K7MQX4PA'), recipe('x')),
    );
  });

  test('only the sender lists their shared recipes', async () => {
    await assertSucceeds(setDoc(doc(as('alice'), 'sharedRecipes/K7MQX4PA'), recipe('alice')));
    await assertSucceeds(
      getDocs(query(collection(as('alice'), 'sharedRecipes'), where('createdBy', '==', 'alice'))),
    );
    await assertFails(getDocs(collection(as('bob'), 'sharedRecipes')));
  });

  test('expired copies are hidden from others, not from the sender', async () => {
    const past = Timestamp.fromMillis(Date.now() - 60000);
    await assertSucceeds(
      setDoc(doc(as('alice'), 'sharedRecipes/OLD23456'), recipe('alice', { expiresAt: past })),
    );
    await assertFails(getDoc(doc(as('bob'), 'sharedRecipes/OLD23456')));
    await assertSucceeds(getDoc(doc(as('alice'), 'sharedRecipes/OLD23456')));
  });
});
