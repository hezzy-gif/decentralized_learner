module decent_learner::decent_learner {
    // imports
    use sui::sui::SUI;
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use sui::tx_context::{Self, TxContext};
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
        courses: vector<ID>, // List of course IDs available on the portal
        payments: Table<ID, Receipt>, // Table of payment receipts
        portal: address, // Address of the portal owner
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
        price: u64, // Price of the course in SUI tokens
    }
    
    struct CourseDetails has copy, drop {
        title: String, // Title of the course
        url: String, // URL of the course content
        educator: address, // Address of the course educator
        duration: u64, // Duration of the course in milliseconds
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
    public fun add_portal(
        ctx: &mut TxContext
    ) : Portal {
        let id = object::new(ctx); // Generate a new unique ID
        Portal {
            id,
            balance: balance::zero<SUI>(), // Initialize balance to zero
            courses: vector::empty<ID>(), // Initialize empty courses list
            payments: table::new<ID, Receipt>(ctx), // Initialize empty payments table
            portal: tx_context::sender(ctx), // Set the portal owner to the transaction sender
        }
    }

    // Function to add a new student
    public fun add_student(
        student: address,
        ctx: &mut TxContext
    ) : Student {
        let id = object::new(ctx); // Generate a new unique ID
        Student {
            id,
            student,
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
    ) : Course {
        let id = object::new(ctx); // Generate a new unique ID
        let course = Course {
            id,
            title,
            url,
            educator,
            price,
            duration,
        };

        // Add course to portal's course list
        vector::push_back(&mut portal.courses, object::id(&course));
        course
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
        course: &mut Course,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Check if student has sufficient balance
        assert!(balance::value(&student.balance) >= course.price, EInsufficientBalance);

        let course_id = object::uid_to_inner(&course.id);

        // Check if the course is valid
        assert!(vector::contains<ID>(&portal.courses, &course_id), EInvalidCourse);

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

    // Function to issue a certificate to the student for completing a course
    public fun get_certificate(
        student: &mut Student,
        course: &Course,
        receipt: &Receipt,
        clock: &Clock,
        ctx: &mut TxContext
    ): Certificate {
        let course_id = object::uid_to_inner(&course.id);
        
        // Check if the receipt belongs to the student and the course is valid
        assert!(object::id(student) == receipt.student_id, EInvalidCourse);
        assert!(vector::contains<ID>(&student.courses, &course_id), EInvalidCourse);
        assert!(!vector::contains<ID>(&student.completed_courses, &course_id), EAlreadyEnrolled);
        assert!(clock::timestamp_ms(clock) >= receipt.paid_date + course.duration, EIncompleteCourseDuration);

        // Mark course as completed
        vector::push_back(&mut student.completed_courses, course_id);

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
        portal: &mut Portal, 
        amount: u64, 
        ctx: &mut TxContext
    ) : Coin<SUI> {
        // Check if the transaction sender is the portal owner
        assert!(portal.portal == tx_context::sender(ctx), ENotPortal);
        // Check if the portal has sufficient balance
        assert!(amount <= balance::value(&portal.balance), EInsufficientBalance);

        // Withdraw the specified amount from the portal's balance
        let coin = coin::take(&mut portal.balance, amount, ctx);
        coin
    }

    // Function to list all courses in the portal
    public fun list_courses(
        portal: &Portal
    ): vector<ID> {
        portal.courses
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
