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
	   		
