USE ERP


----------------------- JOIN 연습
SELECT 
A.name, 
OBJECT_NAME(A.object_id) as 'Table name',
B.name AS 'Column name',
B.max_length,
B.precision,
B.scale
FROM sys.tables A
JOIN sys.all_columns B ON A.object_id = B.object_id
ORDER BY name


------  JOIN 없이 붙여보기(FROM에 2개 테이블을 호출할 수 있음)

SELECT 
	A.name,
	OBJECT_NAME(A.object_id) AS 'Table name',
	B.name AS 'Column name',
	B.max_length,
	B.precision,
	B.scale
  FROM 
	sys.tables AS A,
	sys.all_columns AS B
 WHERE 
	A.object_id = B.object_id
ORDER BY
	name
		

--------- 인라인뷰 연습 (FROM 절 서브쿼리)
--------- 인라인뷰를 사용해서 컬럼 개수가 10개 이상인 테이블들의 이름과 컬럼 개수 찾기

SELECT
	T.Tablename,
	T.Columncount
  FROM --- 테이블의 이름과 개수 카운트하는 테이블 만들기
       ( SELECT
			A.name AS Tablename,
			COUNT(B.Column_id) AS Columncount
		   FROM 
			 sys.tables AS A
		   JOIN
			sys.all_columns AS B 
			ON 
			 A.object_id = B.object_id
		   GROUP BY 
			 A.name
		  -- HAVING Columncount > 10 
		  /* 위 방식으로 HAVING이 안되는 이유
		   SQL은 아래와 같은 논리적 순서에 따라 쿼리를 처리한다
		   FROM/JOIN => WHERE => GROUP BY => HAVING => SELECT = > ORDER BY
		   HAVING이 SELECT 보다 먼저 처리되기 때문에 Columncount 를 읽지 못한다
		  */
		) AS T
	WHERE
		T.Columncount > 10


SELECT
A.name AS Tablename,
COUNT(B.Column_id) AS Columncount
FROM 
	sys.tables AS A
JOIN
sys.all_columns AS B 
ON 
	A.object_id = B.object_id
GROUP BY 
	A.name
HAVING COUNT(B.column_id) > 10 -- 이렇게 바꿔주면 정상 작동함)
	 

--- 스칼라 서브쿼리
/*
	단 하나의 값, 즉 1개의 행, 1개의 컬럼만 반환하는 서브쿼리
	쿼리 결과가 오직 값 하나인 (SELECT --- 구문 )
*/

SELECT 
	name AS TableName,
	(SELECT COUNT(*) FROM sys.tables ) AS TotalTableCount
  FROM 
	sys.tables;


---  스칼라 서브쿼리를 통해서 sys.tables 의 각 테이블 이름 옆에 해당 테이블이 가진 컬럼의 개수를 표시

SELECT
	A.name AS TableName,
	(SELECT
		COUNT(*)
	  FROM 
		sys.all_columns AS B
	 WHERE 
		A.object_id = B.object_id
	)
  FROM sys.tables AS A
  
/*
쿼리 동작 순서
상호 연관 서브쿼리의 전형적인 예시.
바깥쪽 쿼리의 각 행에 대해 서브쿼리가 다시 실행되는 방식으로 동작함

서브쿼리가 독립적으로 실행되지 않고, 바깥쪽 쿼리의 값을 받아서 실행된다.

매핑 과정이 아닌, 바깥쪽 쿼리가 한 줄씩 결과를 만들때,
각 줄에 필요한 값을 계산해서 채워넣는 방식.

=> SELECT 절의 각 항목들은 현재 처리중인 한 줄의 일부로서 동시에 계산됨
*/

 -- 'ZZ\_FI%MAL' ESCAPE '\'


 -- DB 테이블중에서 컬럼이 15개 이상인 테이블과 모든 컬럼 이름 추출
 SELECT
	OBJECT_NAME(T.object_id) AS TABLE_NAME,
	C.name AS COLUMN_NAME
   FROM
	(SELECT
		A.object_id,
		COUNT(B.column_id) AS COLUMN_CNT
	   FROM 
		sys.tables A
	   JOIN
		sys.all_columns B
	     ON A.object_id = B.object_id
	GROUP BY A.object_id
	HAVING COUNT(B.column_id) > 15
	) T
	JOIN sys.all_columns C ON T.object_id = C.object_id
	ORDER BY T.COLUMN_CNT ASC

	
