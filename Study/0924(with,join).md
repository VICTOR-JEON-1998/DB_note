DB에서 제일 중요한 것은 “안정성”

MSSQL 주무기 + MongoDB 실력을 키우고

DA 역량까지 강화하면 DATA 풀스택임.

쿼리를 많이 짜봐야 튜닝을 잘함

APM 드래그해서 쿼리들 살펴보고 최적화해보는 연습 해보면 재밌음.

일대다 ERD

[고객] ──|────────< [주문]

없는 경우도 고려한다면

앞에 o를 붙임

VLOOKUP

```sql
-- 공부 거리

'%_INFO_%M '

'%\_INFO\_%M' 

SELECT 
C.TABLE_NAME,
C.COLUMN_NAME,
C.ORDINAL_POSITION,
C.COLUMN_DEFAULT,
T.create_date,
T.modify_date
FROM INFORMATION_SCHEMA.COLUMNS C
JOIN  sys.tables T
ON C.TABLE_NAME = T.name
WHERE 1=1
AND C.TABLE_NAME LIKE '%\_INFO\_%M' ESCAPE '\'
--AND C.TABLE_NAME LIKE '%INFO%' 
--AND C.TABLE_NAME LIKE '___BANK_%M' ESCAPE '\'
--AND C.TABLE_NAME LIKE '%D'
AND T.modify_date > '2025-06-01'

```

--- 업무 단위 별로 가장 최근에 MODIFY 된 것들 찾기

MSSQL 문자열 자르기 

```sql
SELECT 
LEFT(C.TABLE_NAME,2) AS "업무",
C.TABLE_NAME,
C.COLUMN_NAME,
C.ORDINAL_POSITION,
C.COLUMN_DEFAULT,
T.create_date,
T.modify_date
FROM INFORMATION_SCHEMA.COLUMNS C
JOIN  sys.tables T
ON C.TABLE_NAME = T.name
WHERE 1=1
AND C.TABLE_NAME LIKE '%\_INFO\_%M' ESCAPE '\'
--AND C.TABLE_NAME LIKE '%INFO%' 
--AND C.TABLE_NAME LIKE '___BANK_%M' ESCAPE '\'
--AND C.TABLE_NAME LIKE '%D'
AND T.modify_date > '2025-06-01'

여기까지는 되는데

GROUP BY LEFT(C.TABLE_NAME,2)
붙으면 안됨

```

업무단위별로 가장 최근에 수정된 것들을 뽑는 쿼리를 이렇게 작성했다

```sql
SELECT 
LEFT(A.TABLE_NAME,2) AS '업무',
MAX(B.modify_date)
FROM INFORMATION_SCHEMA.COLUMNS A
JOIN sys.tables B
ON A.TABLE_NAME = B.name
GROUP BY LEFT(A.TABLE_NAME,2)
```

다만 다른 정보들을 함께 보고싶은데,이렇게하면 볼 수가 없다.

어떻게 해결할까?

WITH를 써서 해결해보자.

with로 감싸고,  그 다음에 JOIN - ON 을 써서 해결하는 방법.

```sql

WITH LatestModify AS (
SELECT 
LEFT(A.TABLE_NAME,2) AS '업무',
MAX(B.modify_date) AS '최근수정일'
FROM INFORMATION_SCHEMA.COLUMNS A
JOIN sys.tables B
ON A.TABLE_NAME = B.name
GROUP BY LEFT(A.TABLE_NAME,2)
)
SELECT *
FROM LatestModify A
JOIN sys.tables B
on A.[업무] = LEFT(B.name,2) 
AND A.[최근수정일] = B.modify_date

```

SP_DBA_HELP 

SP_DBA_SESSION

SP_DBA_SYSTEMINFO → 현재 접속되어있는 DB 정보 확인하기

SP_DBA_WHOISACTIVE →

뷰 : 쿼리 성능 최적화가 힘듦

### INDEX

access의 개념

DB에서 검색 속도를 빠르게 하기 위해 사용하는 자료 구조

특정 컬럼의 값을 빠르게 찾을 수 있도록 도와준다

### 시퀀스

자동 증가하는 숫자를 생성하는 기능

독립적인 객체로서 테이블과 별개로 관리함 

중복 방지 

빠르고 효율적

### 채번테이블

별도의 테이블을 두고 현재 번호를 저장/갱신하는 방식

### 인라인뷰

### 서브쿼리

### 스칼라쿼리
