final repo = AccountRepository();

await repo.addAccount(
Account(
id: '1',
name: 'Test User',
phone: '123456789',
email: 'test@gmail.com',
amount: 500,
dueDate: DateTime.now(),
status: 'pending',
lastContactDate: DateTime.now(),
),
);

final data = await repo.getAccounts();
print(data);