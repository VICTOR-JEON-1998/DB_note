테이블뿐만 아니라 컬럼도 통계가 존재한다.

테이블 수정, 컬럼 수정 후에는 통계를 만들어줘야 한다.

sys.stats 테이블에 통계 정보가 담겨있다

EXEC sp_dba_make_stats DB명, 테이블명, 컬럼명

SELECT object_name(object_id), * FROM sys.stats

⇒ 오브젝트 id로 오브젝트 name 을 뽑을 수 있다

SELECT object_name(object_id), * FROM sys.stats WHERE name = ‘컬럼명’

으로 컬럼에 대한 통계 정보 확인하고

sp_dba_make_stats 로 통계 쿼리 생성하고

DROP 후 CREATE 진행

> 페이징 처리
> 

> SQL Isolation level
> 
- Read committed

> Exist , Not Exist 는 1개씩 조건을 검증한다
> 

> JOIN - ON → 묶어놓고 조건을 검증한다는 점에서 EXIST, NOT EXIST와 차이가 있을 수 있다
> 

> Plan handle , Plan cache
> 

SQL Server는 동일한 쿼리가 반복 실행될 때 성능을 높이기 위해서 실행 계획을 캐시에 저장한다.

하지만, 파라미터의 값이 변했는데도 기존의 계획이 그대로 사용되면 성능 저하가 발생할 수 있다.

Parameter sniffing은 최초 실행 시 입력된 파라미터 값을 기준으로 실행 계획이 생성/캐시 되는 현상인데,
이 계획이 이후 다른 파라미터 값에도 동일하게 사용되면, 데이터 분포에 따라 비효율적인 실행 계획을 계속 사용할 수 있게 된다

통계가 오래되어 특정 값의 선택도를 제대로 반영하지 못할 때 문제가 된다.

- 모니터링 툴에서 느린 쿼리를 찾아볼 수 있다
- Plan Handle 에 실행 계획이 잡혀있는데, ELAPSE TIME이 큰 쿼리들은 보통 PLAN CACHE가 동기화되지 않은 것들이 많다
    - 파라미터에 의해서 실행 계획을 잡는다 : Parameter Sniffing에 의해 오래된 파라미터 정보를 갖고있다면 문제가 발생할 수 있다
    - 대부분 Plan Cache를 초기화 해주면 해결된다

DB 인스턴스가 존재하고 DB자체가 존재한다

DB

DB instance는 파일들을 보기위해 열어서 보고, 편집하고, 저장하기 위해 실행시킨 프로그램이다

> mdf , ndf , ldf
> 

mdf : 주 데이터파일

ndf : 보조 데이터파일

ldf : 트랜잭션 로그 파일
