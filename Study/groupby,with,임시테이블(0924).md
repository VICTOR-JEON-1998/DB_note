```sql

SELECT
LEFT(name,2) AS '업무',
name,
MAX(modify_date)
FROM sys.tables 
GROUP BY LEFT(name,2), name -- 이건 실행이 된다
/*
위 쿼리는 업무 , name 을 모두 groupby해서 봅아버린다
*/

SELECT
LEFT(name,2) AS '업무',
name,
MAX(modify_date)
FROM sys.tables 
GROUP BY LEFT(name,2) -- 이건 실행이 안되고

-----------------------------------------

SELECT
LEFT(name,2) AS '업무',
MAX(modify_date) 
FROM sys.tables 
GROUP BY LEFT(name,2) -- 이건 그냥 되는데
-- WITH로 감싸게 되면

WITH Mytable AS
(SELECT
LEFT(name,2) AS '업무',
MAX(modify_date) 
FROM sys.tables 
GROUP BY LEFT(name,2)
)
SELECT *
FROM Mytable
-- 이건 오류가 발생함. WITH로 감싸진 테이블들의 컬럼은 모두 별칭이 있어야 됨. (맞는건가 확인 필요)



WITH Mytable AS
(SELECT
LEFT(name,2) AS '업무',
MAX(modify_date) AS '최근수정일'
FROM sys.tables 
GROUP BY LEFT(name,2)
)
SELECT *
FROM Mytable

-- 이건 오류 발생 안함

-- 아래처럼 하면 원하는 결과 검색이 가능하다

WITH Mytable AS
(SELECT
LEFT(name,2) AS '업무',
MAX(modify_date) AS '최근수정일'
FROM sys.tables 
GROUP BY LEFT(name,2)
)
SELECT *
FROM sys.tables A
JOIN Mytable ON Mytable.[업무] = LEFT(A.name,2) AND Mytable.[최근수정일] = A.modify_date

--------------------------------------------------------
-----------임시테이블

SELECT
LEFT(name,2) [업무],
MAX(modify_date) [최근수정일]
into #Mytable    -- # : 현재 세션에서만 임시테이블 유지 ## : 다른 세션에서도 임시테이블 유지
FROM sys.tables 
GROUP BY LEFT(name,2)

----------------

SELECT *
FROM sys.tables A
JOIN #Mytable Mytable ON Mytable.[업무] = LEFT(A.name,2) AND Mytable.[최근수정일] = A.modify_date 




```
