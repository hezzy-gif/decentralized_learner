module decent_learner::decent_learner {
    // Imports
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
    use sui::event::{Self, Event};

    // Struct definitions
    struct Portal has key, store {
        id: UID,
        balance: Balance<SUI>,
        courses: vector<ID>,
        payments: Table<ID, Receipt>,
        portal: address,
        administrators: vector<address>,
    }

    // Struct to represent a student.
    struct Student has key, store {
        id: UID,
        student: address,
        balance: Balance<SUI>,
        courses: vector<ID>,
        completed_courses: vector<ID>,
    }

    // Struct to represent a course.
    struct Course has key, store {
        id: UID,
        title: String,
        url: String,
        educator: address,
        price: u64,
    }

    // Struct to represent a receipt.
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
    const EUnauthorizedAccess: u64 = 3;
    const ETransferFailed: u64 = 4;

    // Event definitions
    struct DepositEvent has copy, drop {
        student: address,
        amount: u64,
    }

    struct EnrollEvent has copy, drop {
        student: address,
        course: ID,
        amount: u64,
    }

    struct CompleteCourseEvent has copy, drop {
        student: address,
        course: ID,
    }

    // Functions for managing the e-learning platform.

    // Add a portal
    public fun add_portal(
        ctx: &mut TxContext
    ): Portal {
        let id = object::new(ctx);
        Portal {
            id,
            balance: balance::zero<SUI>(),
            courses: vector::empty<ID>(),
            payments: table::new<ID, Receipt>(ctx),
            portal: tx_context::sender(ctx),
            administrators: vector::empty<address>(),
        }
    }

    // Add a student
    public fun add_student(
        student: address,
        ctx: &mut TxContext
    ): Student {
        let id = object::new(ctx);
        Student {
            id,
            student,
            balance: balance::zero<SUI>(),
            courses: vector::empty<ID>(),
            completed_courses: vector::empty<ID>(),
        }
    }

    // Add a course
    public fun add_course(
        title: String,
        url: String,
        educator: address,
        price: u64,
        ctx: &mut TxContext
    ): Course {
        let id = object::new(ctx);
        Course {
            id,
            title,
            url,
            educator,
            price,
        }
    }

    // Student deposit
    public fun student_deposit(
        student: &mut Student,
        amount: Coin<SUI>,
        ctx: &mut TxContext,
    ) {
        let coin_balance = coin::into_balance(amount);
        balance::join(&mut student.balance, coin_balance);
        
        // Log event
        let event = DepositEvent { student: student.student, amount: balance::value(&coin_balance) };
        event::emit(ctx, event);
    }

    // Student enroll
    public fun enroll(
        student: &mut Student,
        course: &Course,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Check if student is already enrolled in the course
        let is_enrolled = vector::contains(&student.courses, object::id(course));
        assert!(!is_enrolled, EAlreadyEnrolled);

        // Ensure student has sufficient balance
        assert!(balance::value(&student.balance) >= course.price, EInsufficientFunds);

        // Handle payment
        let payment = coin::take(&mut student.balance, course.price, ctx);
        let transfer_result = transfer::public_transfer(payment, course.educator);
        assert!(transfer_result, ETransferFailed);

        // Create receipt
        let receipt = Receipt {
            id: object::new(ctx),
            student_id: object::id(student),
            course_id: object::id(course),
            amount: course.price,
            paid_date: clock::timestamp_ms(clock),
        };

        // Add receipt to portal's payments table
        table::add(&mut Portal::payments, receipt.id, receipt);

        // Enroll student in the course
        vector::push_back(&mut student.courses, object::id(course));
        
        // Log event
        let event = EnrollEvent { student: student.student, course: object::id(course), amount: course.price };
        event::emit(ctx, event);
    }

    // Mark course as completed
    public fun complete_course(
        student: &mut Student,
        course_id: ID,
        ctx: &mut TxContext
    ) {
        // Check if student is enrolled in the course
        let is_enrolled = vector::contains(&student.courses, course_id);
        assert!(is_enrolled, EAlreadyEnrolled);

        // Mark course as completed
        vector::push_back(&mut student.completed_courses, course_id);
        
        // Log event
        let event = CompleteCourseEvent { student: student.student, course: course_id };
        event::emit(ctx, event);
    }

    // Helper function to check authorization
    fun is_authorized(portal: &Portal, ctx: &TxContext, role: String): bool {
        let sender = tx_context::sender(ctx);
        role == "portal" && sender == portal.portal || role == "administrator" && vector::contains(&portal.administrators, sender)
    }

    // Add a course with authorization check
    public fun authorized_add_course(
        portal: &mut Portal,
        title: String,
        url: String,
        educator: address,
        price: u64,
        ctx: &mut TxContext
    ): Course {
        // Check if the sender is authorized as portal or administrator
        assert!(is_authorized(portal, ctx, "portal") || is_authorized(portal, ctx, "administrator"), EUnauthorizedAccess);

        let id = object::new(ctx);
        let course = Course {
            id,
            title,
            url,
            educator,
            price,
        };

        // Add course ID to portal's courses
        vector::push_back(&mut portal.courses, object::id(&course));

        course
    }

    // Add administrator to the portal
    public fun add_administrator(
        portal: &mut Portal,
        new_admin: address,
        ctx: &mut TxContext
    ) {
        // Check if the sender is authorized as portal
        assert!(is_authorized(portal, ctx, "portal"), EUnauthorizedAccess);

        vector::push_back(&mut portal.administrators, new_admin);
    }
}
