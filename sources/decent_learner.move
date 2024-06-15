module decent_learner::decent_learner {
    // imports
    use sui::sui::SUI;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::table::{Self, Table};

    use std::string::String;
    use std::vector;

    // Error definitions
    const ENotPortal: u64 = 0; // Error code for invalid portal
    const EInsufficientBalance: u64 = 1; // Error code for insufficient balance
    const EAlreadyEnrolled: u64 = 2; // Error code for already enrolled course
    const EInvalidCourse: u64 = 3; // Error code for invalid course
    const EIncompleteCourseDuration: u64 = 4; // Error code for incomplete course duration
    const ENotEnrolled: u64 = 5; // Error code for not enrolled course


    // Struct definitions

    // Struct to represent the e-learning portal
    struct Portal has key, store {
        id: UID, // Unique identifier for the portal
        balance: Balance<SUI>, // Balance of SUI tokens for the portal
        courses: Table<ID, Course>, // List of course IDs available on the portal
        payments: Table<ID, Receipt>, // Table of payment receipts
    }

    struct PortalCap has key {
        id: UID,
        to: ID
    }

    // Struct to represent a student
    struct Student has key, store {
        id: UID, // Unique identifier for the student
        student: address, // Address of the student
        balance: Balance<SUI>, // Balance of SUI tokens for the student
        courses: vector<ID>, // List of course IDs the student is enrolled in
        completed_courses: vector<ID>, // List of completed course IDs
    }

    // Struct to represent a course
    struct Course has key, store {
        id: UID, // Unique identifier for the course
        title: String, // Title of the course
        url: String, // URL of the course content
        educator: address, // Address of the course educator
        duration: u64, // Duration of the course in milliseconds
        students: Table<address, bool>, // represents the students education
        price: u64, // Price of the course in SUI tokens
    }
    // Struct to represent a receipt
    struct Receipt has key, store {
        id: UID, // Unique identifier for the receipt
        student_id: ID, // ID of the student who made the payment
        course_id: ID, // ID of the course paid for
        amount: u64, // Amount paid in SUI tokens
        paid_date: u64, // Timestamp of the payment
    }

    // Struct to represent a certificate
    struct Certificate has key, store {
        id: UID, // Unique identifier for the certificate
        student_id: ID, // ID of the student
        course_id: ID, // ID of the course
        started_date: u64, // Timestamp when the course was started
        issued_date: u64, // Timestamp when the certificate was issued
    }

    // Functions for managing the e-learning platform

    // Function to add a new portal
    public fun new_portal(
        ctx: &mut TxContext
    ) : (Portal, PortalCap) {
        let id = object::new(ctx); // Generate a new unique ID
        let inner_ = object::uid_to_inner(&id);
        let portal = Portal {
            id,
            balance: balance::zero<SUI>(), // Initialize balance to zero
            courses: table::new(ctx), // Initialize empty courses list
            payments: table::new<ID, Receipt>(ctx), // Initialize empty payments table
        };
        let cap = PortalCap {
            id: object::new(ctx),
            to: inner_
        };
        (portal, cap)
    }

    // Function to add a new student
    public fun add_student(
        ctx: &mut TxContext
    ) : Student {
        let id = object::new(ctx); // Generate a new unique ID
        Student {
            id,
            student: sender(ctx),
            balance: balance::zero<SUI>(), // Initialize balance to zero
            courses: vector::empty<ID>(), // Initialize empty enrolled courses list
            completed_courses: vector::empty<ID>(), // Initialize empty completed courses list
        }
    }

    // Function to add a new course
    public fun add_course(
        portal: &mut Portal,
        title: String,
        url: String,
        educator: address,
        price: u64,
        duration: u64,
        ctx: &mut TxContext
    ) {
        let id = object::new(ctx); // Generate a new unique ID
        let inner = object::uid_to_inner(&id);
        let course = Course {
            id,
            title,
            url,
            educator,
            price,
            students: table::new(ctx),
            duration,
        };
        // Add course to portal's course list
        table::add(&mut portal.courses, inner, course);
    }

    // Function for student to deposit SUI tokens
    public fun deposit(
        student: &mut Student,
        coin: Coin<SUI>,
    ) {
        coin::put(&mut student.balance, coin);
    }

    // Function for student to enroll in a course
    public fun enroll(
        portal: &mut Portal,
        student: &mut Student,
        course_: ID,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let course = table::borrow_mut(&mut portal.courses, course_);
        // Check if student has sufficient balance
        assert!(balance::value(&student.balance) >= course.price, EInsufficientBalance);

        let course_id = object::uid_to_inner(&course.id);

        // Check if the student is already enrolled
        assert!(!vector::contains<ID>(&student.courses, &course_id), EAlreadyEnrolled);

        // Deduct the course price from student's balance
        let payment = coin::take(&mut student.balance, course.price, ctx);

        // Transfer the payment to the educator
        transfer::public_transfer(payment, course.educator);
        // Create a new receipt for the payment
        let receipt = Receipt {
            id: object::new(ctx),
            student_id: object::id(student),
            course_id: object::id(course),
            amount: course.price,
            paid_date: clock::timestamp_ms(clock),
        };
        // Add the course to the student's enrolled courses list
        vector::push_back(&mut student.courses, object::id(course));
        // Add the receipt to the portal's payments table
        table::add(&mut portal.payments, object::id(&receipt), receipt);
    }

    public fun approve_student_course(cap: &PortalCap, self: &mut Portal, course_: ID, student: address) {
        assert!(object::id(self) == cap.to, ENotPortal);
        let course = table::borrow_mut(&mut self.courses, course_);
        table::add(&mut course.students, student, true);
    }

    // Function to issue a certificate to the student for completing a course
    public fun get_certificate(
        self: &mut Portal,
        student: &mut Student,
        course_: ID,
        receipt: &Receipt,
        clock: &Clock,
        ctx: &mut TxContext
    ): Certificate {
        let course = table::borrow_mut(&mut self.courses, course_);
        
        // Check if the receipt belongs to the student and the course is valid
        assert!(object::id(student) == receipt.student_id, EInvalidCourse);
        assert!(vector::contains<ID>(&student.courses, &course_), EInvalidCourse);
        assert!(!vector::contains<ID>(&student.completed_courses, &course_), EAlreadyEnrolled);
        assert!(clock::timestamp_ms(clock) >= receipt.paid_date + course.duration, EIncompleteCourseDuration);
        assert!(table::contains(&course.students, sender(ctx)), EAlreadyEnrolled);

        // Mark course as completed
        vector::push_back(&mut student.completed_courses, course_);

        // Create a new certificate
        let certificate = Certificate {
            id: object::new(ctx),
            student_id: object::id(student),
            course_id: object::id(course),
            started_date: receipt.paid_date,
            issued_date: clock::timestamp_ms(clock),
        };
        certificate
    }

    // Function for educator to withdraw funds from the portal
    public fun withdraw(
        cap: &PortalCap,
        portal: &mut Portal, 
        amount: u64, 
        ctx: &mut TxContext
    ) : Coin<SUI> {
        // Check if the transaction sender is the portal owner
        assert!(object::id(portal) == cap.to, ENotPortal);
        // Check if the portal has sufficient balance
        assert!(amount <= balance::value(&portal.balance), EInsufficientBalance);
        // Withdraw the specified amount from the portal's balance
        let coin = coin::take(&mut portal.balance, amount, ctx);
        coin
    }

    // Function to list all enrolled courses for a student
    public fun list_enrolled_courses(
        student: &Student
    ): vector<ID> {
        student.courses
    }

    // Function to list all completed courses for a student
    public fun list_completed_courses(
        student: &Student
    ): vector<ID> {
        student.completed_courses
    }
}
