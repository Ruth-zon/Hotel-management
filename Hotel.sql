
--יצירת מבנה נתונים
CREATE DATABASE RS_HOTEL


--טבלה ראשונה: מועדון
CREATE TABLE clubs
(
club_id INT PRIMARY KEY NOT NULL,
club_type VARCHAR(40),
improvement VARCHAR(50),
payment INT NOT NULL
)

--טבלת לקוחות
CREATE TABLE customers
(
customer_id INT PRIMARY KEY,
[name] VARCHAR(20) NOT NULL,
phone VARCHAR(11) CHECK(PHONE like'___-_______'),
club INT CONSTRAINT fk_cust_club FOREIGN KEY REFERENCES clubs(club_id) ON DELETE CASCADE
)

--טבלת קטגוריות עובדים
CREATE TABLE category
(
category_id INT PRIMARY KEY NOT NULL,
[description] VARCHAR(40)
)

--טבלת עובדים
CREATE TABLE employees
(
employee_id INT PRIMARY KEY  NOT NULL,
employee_name VARCHAR(20) NOT NULL,
phone VARCHAR(11) CHECK(PHONE LIKE'___-_______'),
adress VARCHAR(20),
category INT constraint fk_cutg_emp FOREIGN KEY REFERENCES category(category_id) ON DELETE CASCADE,
salary_per_hour INT,
manager INT constraint fk_emp FOREIGN KEY REFERENCES employees(employee_id) ON DELETE NO ACTION
)

--טבלת אמצעי תשלום
CREATE TABLE method_of_payment
(
method_of_payment_id INT PRIMARY KEY NOT NULL,
[description] VARCHAR(40)
)

--טבלת חדרים
CREATE TABLE rooms 
(
room_num INT IDENTITY(1,1)PRIMARY KEY,
[floor] INT,
[type] VARCHAR(20) CHECK([type] IN('garden','classic', 'special')), 
vacant BIT,
employee INT CONSTRAINT fk_emp_room FOREIGN KEY REFERENCES employees(employee_id) ON DELETE CASCADE,
)

--טבלת הזמנות
CREATE TABLE invitations
(
code INT IDENTITY(100,1) PRIMARY KEY,
customer INT not null CONSTRAINT fk_cust_inv FOREIGN KEY REFERENCES customers(customer_id) ON DELETE CASCADE,
room INT NOT NULL CONSTRAINT fk_room_inv FOREIGN KEY REFERENCES rooms(ROOM_NUM) ON DELETE CASCADE,
payment INT NOT NULL,
method_of_payment int CONSTRAINT fk_metpay_inv FOREIGN KEY REFERENCES method_of_payment(method_of_payment_id) ON DELETE CASCADE,
invitation_date DATE  NOT NULL DEFAULT(GETDATE()),
vacant_date DATE,
CONSTRAINT ck_date_inv CHECK(DATEDIFF(dd,invitation_date,vacant_date) >=0)
)

--הכנסת נתונים לטבלאות
INSERT INTO category VALUES(1,'cleaner')
INSERT INTO category VALUES(2,'chamber')
INSERT INTO category VALUES(3,'floor maneger')

INSERT INTO clubs VALUES(1,'staff','3 nights + 1 free',599)
INSERT INTO clubs VALUES(2,'member','child in parents room free',659)
INSERT INTO clubs VALUES(3,'guest','ice cream free all day',699)

INSERT INTO customers VALUES(100,'aharon cohen', '054-8484848', 3)
INSERT INTO customers VALUES(200,'moshe levi', '053-3131313',2)
INSERT INTO customers VALUES(333,'ariel catz','052-7676767',1)

INSERT INTO employees VALUES(111,'efrat navon','052-7171717','ramot 2',3, 80,null)
INSERT INTO employees VALUES(222,'eliahu lerner','050-4141414','hagefen 7',2, 70,111)
INSERT INTO employees VALUES(333,'ariel catz','052-7676767','hateena 8',2, 70,111)

INSERT INTO method_of_payment VALUES(1,'visa')
INSERT INTO method_of_payment VALUES(2,'cash')

INSERT INTO rooms VALUES(0,'garden',0,222)
INSERT INTO rooms VALUES(0,'garden',0,222)
INSERT INTO rooms VALUES(0,'special',0,333)
INSERT INTO rooms VALUES(0,'classic',0,333)

--אינדקס מיון לפי תז לקוחות
CREATE INDEX index_cust
ON customers (customer_id)

--אינדקס מיון לפי חדר, לא כולל מיוחדים
CREATE INDEX index_room
ON rooms ([type])
WHERE rooms.[type] IN('garden','classic')

--מקבל תז לקוח ומחזיר חדר
GO
CREATE FUNCTION find_my_room(@cust_num INT) RETURNS int
BEGIN
	DECLARE @ROOM  AS INT;
	SELECT	@room=room
	FROM invitations
	WHERE customer=@cust_num
	RETURN @ROOM
END
GO
--הרצה
SELECT DBO.find_my_room(333) AS ROOM

--מקבל שם לקוח ומחזיר את קומת החדר
GO
CREATE FUNCTION find_my_floor(@cust_name VARCHAR(20)) RETURNS int
BEGIN
	DECLARE @FLOOR  AS INT;
	SELECT	@FLOOR=[floor]
	FROM invitations JOIN customers ON customer_id=customer JOIN rooms ON room_num=room
	WHERE customers.[name]=@cust_name
	RETURN @FLOOR
END
GO
--הרצה
SELECT DBO.find_my_floor('aharon cohen') AS room

--מוצא את כל החדרים בקומה מסוימת, מחזיר טבלה
GO
CREATE FUNCTION find_vacant_in_floor(@FLOOR INT) RETURNS @output table(room_num int, [type] varchar(20)) AS
BEGIN
	INSERT INTO @output(room_num,[type])
		SELECT room_num,[type]
		FROM rooms
		WHERE vacant=0 AND [floor]=@FLOOR
	RETURN
END
GO
--הרצה
SELECT * FROM dbo.find_vacant_in_floor(0)

--הוספת הזמנה
GO
CREATE PROCEDURE ADD_INVENTION
(
	@id INT,
	@days INT,
	@type VARCHAR(20),
	@method_of_payment VARCHAR(20)
)AS
BEGIN
	DECLARE @methodofpay AS INT , @room AS INT, @payment AS INT
	SELECT @payment = payment
	FROM clubs join customers ON club_id=club 
	WHERE customer_id=@id
	set @payment=@payment*@days
	SELECT TOP 1 @room = room_num
	FROM rooms WHERE vacant=0 and [type] like (@type)
	SELECT @methodofpay =  method_of_payment_id 
	FROM  method_of_payment WHERE [description]=@method_of_payment
	DECLARE @vacantdate AS [date] =dateadd(d,@days,Getdate())
	INSERT INTO invitations VALUES(@id,@room,@payment,@methodofpay,DEFAULT,@vacantdate)
end
GO

execute ADD_INVENTION @id=100,@days=4,@type='classic',@method_of_payment='visa'
execute ADD_INVENTION @id=200,@days=3,@type='garden',@method_of_payment='cash'
execute ADD_INVENTION @id=333,@days=10,@type='special',@method_of_payment='visa'

--טריגר המסמן את החדר כתפוס בעת הזמנה
GO
 CREATE TRIGGER cange_vacant ON invitations 
 AFTER INSERT, UPDATE
 AS 
 DECLARE @ROOM INT
 SELECT @ROOM= room FROM inserted
 UPDATE rooms SET vacant=1 WHERE room_num=@ROOM
 GO

 --להצגת העובד והמנהל קומה של כל חדר
 CREATE VIEW showClubs as 
 (
 select  room_num,employee_name,[floor] ,(select employee_name from employees where employees.employee_id =emp.manager)as manager
 from rooms join employees as emp ON rooms.employee=employee_id

 )