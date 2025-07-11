-- Create a library Database Exercise

-- Basic
-----------------------------------------------------------------------------------------------
Create Database MaritzburgLibraryDB; GO

Use MaritzburgLibraryDB; GO

--Build Members & Books Tables

Create Table LibGuests (
	GuestID Int Identity(1,1) Primary Key,
	FirstName varchar(50) Not NUll,
	LasttName varchar(50) Not NUll,
	Email varchar(100) Not NUll,
	JoinDate datetime default GetDate() Not NUll,
	Phone varchar(15) Not NUll,
	CONSTRAINT Chk_Email Check (Email LIKE '%_@__%_%') --Find out what this can do
	);
GO

--Books

Create Table LibBooks (
	BookID Int Identity(1,1) Primary Key,
	Title varchar(150) Not NUll,
	Author varchar(150) Not NUll,
	YearOfPublish smallint Not NUll,
	Genre varchar(50) Not NUll,
	AddedDate datetime default GetDate() Not NUll,
	CONSTRAINT Chk_YearOfPublish Check (YearOfPublish Between 1000and Year(GetDate()))
	);
GO


--Checkout


Create Table LibCheckout (
	CheckoutID Int Identity(1,1) Primary Key,
	BookID int Not NUll,
	GuestID int Not NUll,
	CheckoutDate datetime default GetDate() Not NUll,
	DueDate AS DATEADD(Week, 3, CheckoutDate) Persisted, --Understand this part too...
	ReturnDate Datetime Null,
	CONSTRAINT FK_LibCheckout_LibBooks Foreign Key (BookID) References LibBooks(BookID),
	CONSTRAINT FK_LibCheckout_LibGuests Foreign Key (GuestID) References LibGuests(GuestID),
	CONSTRAINT FK_ReturnDate Check (ReturnDate IS NULL OR ReturnDate >= CheckoutDate)
	);
GO




-------------------------------------------------------------------------------------
--- Functional Code


--Book Availability Check (Index used)

Create NonClustered Index IDX_LibCheckout_BookStatus ON LibCheckout (BookID, ReturnDate);
GO

----------------------------------------------------------------------------------------------------
--Stored Procedure : Book Checkout

Create Procedure BookCheckout
	@BookID INT,
	@GuestID INT
AS
Begin
	Set NoCount ON; --Explanation pending...

	--Validate Book Still Exists
	If Not Exists (SELECT 1 FROM LibBooks WHERE BookID = @BookID)
	Begin
		RAISERROR('Book does not exist', 16 ,1);
		Return;
	End

	--Validate Guest
		If Not Exists (SELECT 1 FROM LibGuests WHERE GuestID = @GuestID)
	Begin
		RAISERROR('Guest does not exist', 16 ,1);
		Return;
	End

	--Book Availability Check
		If Exists (
			SELECT 1 
			FROM LibCheckout 
			WHERE BookID = @BookID
			AND ReturnDate IS Null
			AND GetDate() < DueDate
			)
				Begin
					RAISERROR('Book has been checked out', 16 ,1);
					Return;
				End


--Create New Checkout 
Insert into LibCheckout (BookID, GuestID) 
	Values (@BookID, @GuestID);

	Print 'Book checkout is successful';
End
Go


-----------------------------------------------------------------------------------------------

--Stored Procedure: Book Returns

Create procedure ReturnBooks
	@CheckoutID INT
AS
Begin
	Set NOCOUNT ON;

	--Verify existing book checkouts & isnt returned
	IF NOT EXISTS (
		Select 1
		from LibCheckout
		Where CheckoutID = @CheckoutID
		AND ReturnDate IS Null
	)
	Begin
		Raiserror('Book checkout unsuccessful or book is already returned', 16, 1);
		Return;
	End


	--Mark Returned books
	Update LibCheckout
	Set ReturnDate = GetDate()
	Where CheckoutID = @CheckoutID;

	PRINT 'Book returned successully';
End
GO


----------------------------------------------------------
--Stored procedure: Members Active Checkouts

 
 Create procedure ActiveGuestCheckouts
	@GuestID int
as
begin
	Select
		b.Title,
		b.Author,
		l.CheckoutDate,
		l.DueDate,
		DaysOverdue = Case
			when GetDate() > l.DueDate then Datediff(Day, l.DueDate, GetDate())
			else 0
		End
	from LibCheckout as l
	join LibBooks as b on l.BookID = b.BookID
	where l.GuestID = @GuestID
	and l.ReturnDate is Null
	order by l.DueDate ASC;
end
GO

-----------------------------------------------------------------------------

--Available books

-- Create Stored Procedure: Get Available Books
CREATE PROCEDURE GetAvailableBooks
    @SearchTerm NVARCHAR(100) = NULL
AS
BEGIN
    SELECT 
        b.BookID,
        b.Title,
        b.Author,
        b.ISBN,
        b.PublishedYear
    FROM Books b
    WHERE NOT EXISTS (
        SELECT 1
        FROM Loans l
        WHERE l.BookID = b.BookID
        AND l.ReturnDate IS NULL
        AND GETDATE() < l.DueDate
    )
    AND (
        @SearchTerm IS NULL 
        OR b.Title LIKE '%' + @SearchTerm + '%'
        OR b.Author LIKE '%' + @SearchTerm + '%'
        OR b.ISBN = @SearchTerm
    );
END
GO

-- Create Stored Procedure: Add New Book
CREATE PROCEDURE AddNewBook
    @ISBN NVARCHAR(20),
    @Title NVARCHAR(200),
    @Author NVARCHAR(100),
    @PublishedYear SMALLINT,
    @Genre NVARCHAR(50) = NULL
AS
BEGIN
    INSERT INTO Books (ISBN, Title, Author, PublishedYear, Genre)
    VALUES (@ISBN, @Title, @Author, @PublishedYear, @Genre);
    
    PRINT 'Book added successfully';
END
GO

-- Create Stored Procedure: Register New Member
CREATE PROCEDURE RegisterMember
    @FirstName NVARCHAR(50),
    @LastName NVARCHAR(50),
    @Email NVARCHAR(100),
    @Phone NVARCHAR(20) = NULL
AS
BEGIN
    INSERT INTO Members (FirstName, LastName, Email, Phone)
    VALUES (@FirstName, @LastName, @Email, @Phone);
    
    PRINT 'Member registered successfully';
END
GO

-- Create View: Book Availability Status
CREATE VIEW BookAvailability AS
SELECT 
    b.BookID,
    b.Title,
    b.Author,
    Availability = CASE 
        WHEN EXISTS (
            SELECT 1 
            FROM Loans l 
            WHERE l.BookID = b.BookID 
            AND l.ReturnDate IS NULL
            AND GETDATE() < l.DueDate
        ) THEN 'Checked Out'
        ELSE 'Available'
    END,
    NextAvailableDate = (
        SELECT MAX(DueDate) 
        FROM Loans 
        WHERE BookID = b.BookID 
        AND ReturnDate IS NULL
    )
FROM Books b;
GO

-- Create Sample Data
INSERT INTO Members (FirstName, LastName, Email, Phone)
VALUES 
('Sarah', 'Johnson', 'sarah.j@email.com', '555-1234'),
('Michael', 'Chen', 'michael.c@email.com', '555-5678');

INSERT INTO Books (ISBN, Title, Author, PublishedYear, Genre)
VALUES 
('978-0451524935', '1984', 'George Orwell', 1949, 'Dystopian'),
('978-0061120084', 'To Kill a Mockingbird', 'Harper Lee', 1960, 'Fiction'),
('978-0743273565', 'The Great Gatsby', 'F. Scott Fitzgerald', 1925, 'Classic');

-- Checkout books
EXEC CheckoutBook @BookID = 1, @MemberID = 1;
EXEC CheckoutBook @BookID = 2, @MemberID = 1;
EXEC CheckoutBook @BookID = 3, @MemberID = 2;

-- Return a book
EXEC ReturnBook @LoanID = 1;

-- Get member's active loans
EXEC GetMemberActiveLoans @MemberID = 1;

-- Get available books
EXEC GetAvailableBooks @SearchTerm = 'Gatsby';

-- Add new book
EXEC AddNewBook 
    @ISBN = '978-0544003415',
    @Title = 'The Hobbit',
    @Author = 'J.R.R. Tolkien',
    @PublishedYear = 1937,
    @Genre = 'Fantasy';

-- Register new member
EXEC RegisterMember 
    @FirstName = 'Emily',
    @LastName = 'Rodriguez',
    @Email = 'emily.r@email.com',
    @Phone = '555-9012';

-- Query book availability view
SELECT * FROM BookAvailability;


























