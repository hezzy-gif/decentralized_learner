module decent_learner::decent_learner {
    // imports
    use sui::sui::SUI;
    use std::vector;
    use sui::transfer;
    use std::string::String;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
    use sui::table::{Self, Table};

    // Struct definitions
    struct Portal has key, store {
        id: UID,
        balance: Balance<SUI>,
        courses: vector<String>,
        payments: Table<ID, Payment>,
        portal: address,
    }

    // Struct to represent a student.
    struct Student has key, store {
        id: UID,
        student: address,
        balance: Balance<SUI>,
        courses: vector<ID>,
        completed_courses: vector<ID>,
    }

    // Struct to represent course
    struct Course has key, store {
        id: UID,
        title: String,
        url: String,
        educator: address,
        price: u64,
    }

    // Struct to represent a receipt
    struct Receipt has key, store {
        id: UID,
        student_id: ID,
        course_id: ID,
        amount: u64,
        paid_date: u64,
    }

    // error definitions
    const ENotPortal: u64 = 0;
    const EInsufficientFunds: u64 = 1;
    const EInsufficientBalance: u64 = 2;

    // Functions for managing the e-learning platform.
    // add portal
    public fun add_portal(
        ctx: &mut TxContext
    ) : Portal {
        let id = object::new(ctx);
        Portal {
            id,
            balance: balance::zero<SUI>(),
            courses: vector::empty<ID>(),
            payments: table::new<ID, Payment>(ctx),
            portal: tx_context::sender(ctx),
        }
    }

    // add student
    public fun add_student(
        student: address,
        ctx: &mut TxContext
    ) : Student {
        let id = object::new(ctx);
        Student {
            id,
            student,
            balance: balance::zero<SUI>(),
            courses: vector::empty<ID>(),
            completed_courses: vector::empty<ID>(),
        }
    }

    // add course
    public fun add_course(
        title: String,
        url: String,
        educator: address,
        price: u64,
        ctx: &mut TxContext
    ) : Course {
        let id = object::new(ctx);
        Course {
            id,
            title,
            url,
            educator,
            price,
        }
    }

    // student deposit
    public fun deposit(
        student: &mut Student,
        amount: Coin<SUI>,
    ) {
        let coin = coin::into_balance(amount);
        balance::join(&mut student.balance, coin);
    }

    // student enroll
    public fun enroll(
        student: &mut Student,
        course: &mut Course,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(balance::value(&student.balance) >= course.price, EInsufficientFunds);

        let payment = coin::take(&mut student.balance, course.price, ctx);

        transfer::public_transfer(payment, course.educator);

        let receipt = Receipt {
            id: object::new(ctx),
            student_id: object::id(student),
            course_id: object::id(course),
            amount: course.price,
            paid_date: clock::timestamp_ms(clock),
        };
        
        vector::push_back(&mut student.courses, object::id(course));
    }
}