> DOP (max Degree Of Parellism)
> 

DB가 하나의 쿼리를 처리할 때 동시에 사용하는 CPU 코어의 수

> Trigger 트리거
> 

특정 테이블에 INSERT , UPDATE, DELETE 같은 이벤트가 발생했을 대 자동으로 실행되도록 미리 정의해 둔 SQL 프로시저

→ 언제 바꾸나?

- DB 스키마 구조가 변경되었을 때
    - 트리거가 기존 스키마 구조를 기억하고 수행되기 때문이다

> Statistics 통계
> 

테이블 데이터 분포 요약 정보

쿼리 옵티마이저가 더 빠르고 효율적인 쿼리 실행 계획을 세우는 데 사용하는 핵심적인 메타데이터

쿼리 옵티마이저 : 네비게이션

인덱스 : 도로망

통계 : 실시간 교통정보

→ 언제 바꾸나?

- 대량의 데이터 변경이 있었을 때 (데이터 분포가 변했기 때문에)
- 쿼리가 갑자기 느려졌을 때

---

## DB 백업

1. 백업이 필요한 DB서버에 접속하여 NAS 스토리지에 백업본을 넣어둔다
2. 복구가 필요한 DB서버에 접속하여 백업본을 NAS 스토리지에서 E드라이브로 옮긴다. (RESTORE 외부)
3. 복구가 필요한 DB서버에서 SSMS 접속하여 데이터베이스 → 복구 기능

<img width="1651" height="908" alt="image" src="https://github.com/user-attachments/assets/fe3aa0f2-d751-4ee7-8b3b-79c4efe63a3d" />


1. 디바이스에서 데이터베이스 → 복구가 필요한 백업본을 찾는다
2. 대상 : 데이터베이스에서 복구할 백업본의 이름을 변경한다 예시) ERP ⇒ ERP_TT

<img width="1651" height="908" alt="image" src="https://github.com/user-attachments/assets/be9714c7-031c-4970-8ce3-0c774f34ecd9" />


1. “파일” 에서 모든 파일을 폴더 위치로 변경 클릭 후, 데이터 파일 폴더, 로그 파일 폴더 경로를 E드라이브의 RESTORE를 선택한다
    1. RECOVERY / RESTORE는 다른 것이다
    2. RESTORE : DB를 불러와서 바로 사용할 수 있게 만듦. 

<img width="1237" height="716" alt="image" src="https://github.com/user-attachments/assets/2d6bf5f4-8bb2-48da-acdc-44e9e5bf0925" />


1. “옵션” 에서 복구 상태를 트랜잭션 로그 백업 유무에 따라 다르게 선택한다.
2. 비상 로그 백업은 **비활성화** 한다!

---

### DB 백업 후 진행해야 하는 것들

> 통계
> 

> 로그인 / DB 사용자 설정
> 

> 마스킹 (개인정보처리)
> 
- 운영은 개인정보 마스킹이 안되어 있지만, 타 DB들은 개인정보가 마스킹되어있다

> 암호화 키값
> 

> 대소문자 구별
> 

> AUDIT 정책 생성
> 

> lock ascalation
> 

> Trigger
> 

---

### TASK - 축소 - 파일을 통해 사용하지 않는 공간 해제 가능

<img width="1027" height="870" alt="image" src="https://github.com/user-attachments/assets/5ada1be5-91d3-40aa-b8d5-d58ce50f6ab4" />

디스크 조각 모음 처럼 동작 가능

### 로그인과 DB사용자는 다른 개념.

로그인은 서버에 대한 “인증”이고 사용자는 데이터베이스에 대한 “허가”이다.

DBMS(데이터베이스서버) : 아파트 단지 전체

로그인 : 아파트 단지 정문 출입카드 (인증)

데이터베이스 : 단지 내의 개별 아파트

데이터베이스 사용자 : 개별 아파트 현관문 열쇠 (허가)
