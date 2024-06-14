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

    // Struct definitions

    struct Portal has key, store {
        id: UID,
        balance: Balance<SUI>,
        courses: Table<ID, Course>, // Changed to Table for better management
        payments: Table<ID, Receipt>,
        portal_owner: address,
    }

    struct Student has key, store {
        id: UID,
        student_address: address,
        balance: Balance<SUI>,
        enrolled_courses: Table<ID, EnrolledCourse>, // Changed to Table for better management
        completed_courses: Table<ID, Certificate>, // Changed to Table for better management
    }

    struct Course has key, store {
        id: UID,
        title: String,
        url: String,
        educator: address,
        duration: u64,
        price: u64,
    }

    struct EnrolledCourse has copy, drop {
        course_id: ID,
        enrollment_date: u64,
    }

    struct Receipt has key, store {
        id: UID,
        student_id: ID,
        course_id: ID,
        amount: u64,
        paid_date: u64,
    }

    struct Certificate has key, store {
        id: UID,
        student_id: ID,
        course_id: ID,
        started_date: u64,
        issued_date: u64,
    }

    // Error definitions
    const ENotPortalOwner: u64 = 0;
    const EInsufficientBalance: u64 = 1;
    const EAlreadyEnrolled: u64 = 2;
    const EInvalidCourse: u64 = 3;
    const EIncompleteCourseDuration: u64 = 4;
    const ENotEnrolled: u64 = 5;
    const EAlreadyCompleted: u64 = 6;

    // Functions

    public fun add_portal(
        ctx: &mut TxContext
    ) : Portal {
        let id = object::new(ctx);
        Portal {
            id,
            balance: balance::zero<SUI>(),
            courses: table::new<ID, Course>(ctx),
            payments: table::new<ID, Receipt>(ctx),
            portal_owner: tx_context::sender(ctx),
        }
    }

    public fun add_student(
        student_address: address,
        ctx: &mut TxContext
    ) : Student {
        let id = object::new(ctx);
        Student {
            id,
            student_address,
            balance: balance::zero<SUI>(),
            enrolled_courses: table::new<ID, EnrolledCourse>(ctx),
            completed_courses: table::new<ID, Certificate>(ctx),
        }
    }

    public fun add_course(
        portal: &mut Portal,
        title: String,
        url: String,
        educator: address,
        price: u64,
        duration: u64,
        ctx: &mut TxContext
    ) : Course {
        assert!(portal.portal_owner == tx_context::sender(ctx), ENotPortalOwner);
        let id = object::new(ctx);
        let course = Course {
            id,
            title,
            url,
            educator,
            price,
            duration,
        };

        table::add(&mut portal.courses, object::id(&course), course);
        course
    }

    public fun deposit(
        student: &mut Student,
        amount: Coin<SUI>,
    ) {
        let coin_balance = coin::into_balance(amount);
        balance::join(&mut student.balance, coin_balance);
    }

    public fun enroll(
        portal: &mut Portal,
        student: &mut Student,
        course_id: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let course = table::borrow_mut(&mut portal.courses, course_id);
        assert!(balance::value(&student.balance) >= course.price, EInsufficientBalance);
        assert!(!table::contains(&student.enrolled_courses, course_id), EAlreadyEnrolled);

        let payment = coin::take(&mut student.balance, course.price, ctx);
        transfer::public_transfer(payment, course.educator);

        let receipt = Receipt {
            id: object::new(ctx),
            student_id: object::id(student),
            course_id,
            amount: course.price,
            paid_date: clock::timestamp_ms(clock),
        };

        let enrollment = EnrolledCourse {
            course_id,
            enrollment_date: clock::timestamp_ms(clock),
        };

        table::add(&mut student.enrolled_courses, course_id, enrollment);
        table::add(&mut portal.payments, object::id(&receipt), receipt);
    }

    public fun get_course_details(
        portal: &Portal,
        course_id: ID
    ): Course {
        table::borrow(&portal.courses, course_id)
    }

    public fun get_certificate(
        student: &mut Student,
        course_id: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ): Certificate {
        let course = table::borrow(&student.enrolled_courses, course_id);
        let enrollment = table::borrow(&student.enrolled_courses, course_id);
        let paid_date = enrollment.enrollment_date;

        assert!(clock::timestamp_ms(clock) >= paid_date + course.duration, EIncompleteCourseDuration);
        assert!(!table::contains(&student.completed_courses, course_id), EAlreadyCompleted);

        let certificate = Certificate {
            id: object::new(ctx),
            student_id: object::id(student),
            course_id,
            started_date: paid_date,
            issued_date: clock::timestamp_ms(clock),
        };

        table::add(&mut student.completed_courses, course_id, certificate);
        certificate
    }

    public fun withdraw(
        portal: &mut Portal,
        amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(portal.portal_owner == tx_context::sender(ctx), ENotPortalOwner);
        assert!(amount <= balance::value(&portal.balance), EInsufficientBalance);

        let amount_to_withdraw = coin::take(&mut portal.balance, amount, ctx);
        transfer::public_transfer(amount_to_withdraw, portal.portal_owner);
    }

    public fun list_courses(
        portal: &Portal
    ): vector<ID> {
        table::keys(&portal.courses)
    }

    public fun list_enrolled_courses(
        student: &Student
    ): vector<ID> {
        table::keys(&student.enrolled_courses)
    }

    public fun list_completed_courses(
        student: &Student
    ): vector<ID> {
        table::keys(&student.completed_courses)
    }

    // New Functions

    // Function to update course details
    public fun update_course(
        portal: &mut Portal,
        course_id: ID,
        new_title: Option<String>,
        new_url: Option<String>,
        new_price: Option<u64>,
        new_duration: Option<u64>,
        ctx: &mut TxContext
    ) {
        assert!(portal.portal_owner == tx_context::sender(ctx), ENotPortalOwner);
        let course = table::borrow_mut(&mut portal.courses, course_id);

        if (new_title != none()) {
            course.title = option::unwrap(new_title);
        }
        if (new_url != none()) {
            course.url = option::unwrap(new_url);
        }
        if (new_price != none()) {
            course.price = option::unwrap(new_price);
        }
        if (new_duration != none()) {
            course.duration = option::unwrap(new_duration);
        }
    }

    // Function to remove a course
    public fun remove_course(
        portal: &mut Portal,
        course_id: ID,
        ctx: &mut TxContext
    ) {
        assert!(portal.portal_owner == tx_context::sender(ctx), ENotPortalOwner);
        table::remove(&mut portal.courses, course_id);
    }

    // Function to refund a student for a course
    public fun refund(
        portal: &mut Portal,
        student: &mut Student,
        course_id: ID,
        ctx: &mut TxContext
    ) {
        assert!(portal.portal_owner == tx_context::sender(ctx), ENotPortalOwner);
        let enrollment = table::borrow_mut(&mut student.enrolled_courses, course_id);
        let receipt = table::borrow(&portal.payments, object::id(&enrollment));

        assert!(balance::value(&portal.balance) >= receipt.amount, EInsufficientBalance);

        let refund_coin = coin::take(&mut portal.balance, receipt.amount, ctx);
        transfer::public_transfer(refund_coin, student.student_address);

        table::remove(&mut student.enrolled_courses, course_id);
        table::remove(&portal.payments, object::id(&enrollment));
    }
}
