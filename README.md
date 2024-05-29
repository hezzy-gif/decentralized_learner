# Decentralized Learner

To create a decentralized e-learning platform where users can enroll in courses, and educators can offer their expertise. Payments are handled through a decentralized finance (DeFi) mechanism, allowing seamless transactions and financial incentives for both learners and educators.

## Overview of `decent_learner::decent_learner` Module

This module provides functionalities for managing an e-learning platform with the following key components:

- **Portal**: Represents the e-learning platform.
- **Student**: Represents a student enrolled in the platform.
- **Course**: Represents a course offered on the platform.
- **Receipt**: Represents a payment receipt for course enrollment.

### Struct Definitions

1. **Portal**
   - `id: UID`: Unique identifier for the portal.
   - `balance: Balance<SUI>`: Balance of the portal in SUI coins.
   - `courses: vector<String>`: List of courses available on the portal.
   - `payments: Table<ID, Payment>`: Payments table mapping IDs to payments.
   - `portal: address`: Address of the portal.

2. **Student**
   - `id: UID`: Unique identifier for the student.
   - `student: address`: Address of the student.
   - `balance: Balance<SUI>`: Student's balance in SUI coins.
   - `courses: vector<ID>`: List of courses the student is enrolled in.
   - `completed_courses: vector<ID>`: List of courses the student has completed.

3. **Course**
   - `id: UID`: Unique identifier for the course.
   - `title: String`: Title of the course.
   - `url: String`: URL where the course is hosted.
   - `educator: address`: Address of the educator.
   - `price: u64`: Price of the course in SUI coins.

4. **Receipt**
   - `id: UID`: Unique identifier for the receipt.
   - `student_id: ID`: ID of the student.
   - `course_id: ID`: ID of the course.
   - `amount: u64`: Amount paid.
   - `paid_date: u64`: Timestamp of the payment.

### Error Definitions

- `ENotPortal: u64 = 0`: Error when the portal is not found.
- `EInsufficientFunds: u64 = 1`: Error when the student has insufficient funds.
- `EInsufficientBalance: u64 = 2`: Error when the balance is insufficient for the operation.

### Functions

1. **add_portal**
   - Creates and returns a new `Portal` instance.
   - Sets the initial balance to zero and initializes courses and payments.

2. **add_student**
   - Creates and returns a new `Student` instance.
   - Sets the initial balance to zero and initializes the courses and completed_courses vectors.

3. **add_course**
   - Creates and returns a new `Course` instance.
   - Initializes the course with the provided title, URL, educator, and price.

4. **deposit**
   - Deposits a specified amount of SUI coins into the student's balance.

5. **enroll**
   - Enrolls a student in a course.
   - Verifies that the student has sufficient funds.
   - Transfers the course price from the student's balance to the educator's address.
   - Creates a `Receipt` for the transaction.
   - Adds the course to the student's list of enrolled courses.

### Suggestions for Improvements

1. **Error Handling**: Use descriptive error messages and consistent error handling throughout the module.
2. **Function Documentation**: Add comments and documentation for each function to explain their purpose and parameters.
3. **Validation**: Add validation checks for inputs where necessary (e.g., non-empty strings for titles and URLs).
4. **Course Management**: Implement functions to manage courses, such as updating or removing courses.
5. **Completed Courses**: Implement a mechanism to mark courses as completed and move them from the `courses` vector to the `completed_courses` vector.

### Example Usage

Here's an example of how the module might be used:

```rust
fun example_usage(ctx: &mut TxContext, clock: &Clock) {
    // Create a portal
    let portal = decent_learner::add_portal(ctx);

    // Add a student
    let student_address = tx_context::sender(ctx);
    let student = decent_learner::add_student(student_address, ctx);

    // Add a course
    let course = decent_learner::add_course(
        "Introduction to Rust".to_string(),
        "http://example.com/rust".to_string(),
        educator_address,
        100,
        ctx
    );

    // Deposit funds to the student's balance
    decent_learner::deposit(&mut student, some_sui_coin);

    // Enroll the student in the course
    decent_learner::enroll(&mut student, &mut course, clock, ctx);
}
```

## Configure connectivity to a local node

Once the local node is running (using `sui-test-validator`), you should the url of a local node - `http://127.0.0.1:9000` (or similar).
Also, another url in the output is the url of a local faucet - `http://127.0.0.1:9123`.

Next, we need to configure a local node. To initiate the configuration process, run this command in the terminal:

```
sui client active-address
```

The prompt should tell you that there is no configuration found:

```
Config file ["/home/codespace/.sui/sui_config/client.yaml"] doesn't exist, do you want to connect to a Sui Full node server [y/N]?
```

Type `y` and in the following prompts provide a full node url `http://127.0.0.1:9000` and a name for the config, for example, `localnet`.

On the last prompt you will be asked which key scheme to use, just pick the first one (`0` for `ed25519`).

After this, you should see the ouput with the wallet address and a mnemonic phrase to recover this wallet. You can save so later you can import this wallet into SUI Wallet.

Additionally, you can create more addresses and to do so, follow the next section - `Create addresses`.

### Create addresses

For this tutorial we need two separate addresses. To create an address run this command in the terminal:

```
sui client new-address ed25519
```

where:

- `ed25519` is the key scheme (other available options are: `ed25519`, `secp256k1`, `secp256r1`)

And the output should be similar to this:

```
╭─────────────────────────────────────────────────────────────────────────────────────────────────╮
│ Created new keypair and saved it to keystore.                                                   │
├────────────────┬────────────────────────────────────────────────────────────────────────────────┤
│ address        │ 0x05db1e318f1e4bc19eb3f2fa407b3ebe1e7c3cd8147665aacf2595201f731519             │
│ keyScheme      │ ed25519                                                                        │
│ recoveryPhrase │ lava perfect chef million beef mean drama guide achieve garden umbrella second │
╰────────────────┴────────────────────────────────────────────────────────────────────────────────╯
```

Use `recoveryPhrase` words to import the address to the wallet app.

### Get localnet SUI tokens

```
curl --location --request POST 'http://127.0.0.1:9123/gas' --header 'Content-Type: application/json' \
--data-raw '{
    "FixedAmountRequest": {
        "recipient": "<ADDRESS>"
    }
}'
```

`<ADDRESS>` - replace this by the output of this command that returns the active address:

```
sui client active-address
```

You can switch to another address by running this command:

```
sui client switch --address <ADDRESS>
```

## Build and publish a smart contract

### Build package

To build tha package, you should run this command:

```
sui move build
```

If the package is built successfully, the next step is to publish the package:

### Publish package

```
sui client publish --gas-budget 100000000 --json
` - `sui client publish --gas-budget 1000000000`
```
