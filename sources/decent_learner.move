module decent_learner::decent_learner {
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
    use sui::mutex::{Self, Mutex};

    // Struct definitions
    struct Portal has key, store {
        id: UID,
        balance: Balance<SUI>,
        courses: vector<ID>,
        payments: Table<ID, Receipt>,
        portal: address,
        lock: Mutex,
    }

    struct Student has key, store {
        id: UID,
        student: address,
        balance: Balance<SUI>,
        courses: vector<ID>,
        completed_courses: vector<ID>,
        lock: Mutex,
    }

    struct Course has key, store {
        id: UID,
        title: String,
        url: String,
        educator: address,
        price: u64,
        lock: Mutex,
    }

    struct Receipt has key, store {
        id: UID,
        student_id: ID,
        course_id: ID,
        amount: u64,
        paid_date: u64,
    }

    // Error definitions
    const ENotPortal: u64 = 0;
    const EInsufficientFunds: u64 = 1;
    const EAlreadyEnrolled: u64 = 2;
    const EInvalidCourse: u64 = 3;
    const EConcurrencyError: u64 = 4;

    // Functions for managing the e-learning platform

    public fun add_portal(ctx: &mut TxContext) : Portal {
        let id = object::new(ctx);
        Portal {
            id,
            balance: balance::zero<SUI>(),
            courses: vector::empty<ID>(),
            payments: table::new<ID, Receipt>(ctx),
            portal: tx_context::sender(ctx),
            lock: mutex::new(ctx),
        }
    }

    public fun add_student(student: address, ctx: &mut TxContext) : Student {
        let id = object::new(ctx);
        Student {
            id,
            student,
            balance: balance::zero<SUI>(),
            courses: vector::empty<ID>(),
            completed_courses: vector::empty<ID>(),
            lock: mutex::new(ctx),
        }
    }

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
            lock: mutex::new(ctx),
        }
    }

    // Function for educator to withdraw funds from portal
    public fun withdraw(portal: &mut Portal, amount: Coin<SUI>, ctx: &mut TxContext) -> bool {
        let _lock = mutex::lock(&mut portal.lock, ctx);

        assert!(tx_context::sender(ctx) == portal.portal, ENotPortal);
        let coin = coin::into_balance(amount);
        if !balance::can_pay(&portal.balance, &coin) {
            return false; // Insufficient balance
        }
        balance::subtract(&mut portal.balance, coin);
        transfer::public_transfer(coin, tx_context::sender(ctx));
        return true; // Successful withdrawal
    }

    // Function to enroll student with validation and duplicate enrollment prevention
    public fun enroll(
        student: &mut Student,
        course: &Course,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let _student_lock = mutex::lock(&mut student.lock, ctx);
        let _course_lock = mutex::lock(&mut course.lock, ctx);

        assert!(balance::value(&student.balance) >= course.price, EInsufficientFunds);
        assert!(object::exists(ctx, object::id(course)), EInvalidCourse);
        assert!(!vector::contains(&student.courses, object::id(course)), EAlreadyEnrolled);

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
        table::add(&mut portal.payments, object::id(&receipt), receipt);
    }
}
