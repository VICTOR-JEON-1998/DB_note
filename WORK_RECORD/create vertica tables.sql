-- MSSQL ERP 테이블 컬럼 정보 뽑는 쿼리

SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    COLUMN_NAME,
    ORDINAL_POSITION,
    DATA_TYPE,
    CHARACTER_MAXIMUM_LENGTH,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'Table name'
ORDER BY ORDINAL_POSITION;


-----------------------
CREATE TABLE BIDWADM_CO.OD_FI_BANK_M
(
    ACUNIT_CD      CHAR(12)        NOT NULL,
    BANK_CD        CHAR(9)         NOT NULL,
    BANK_NM        VARCHAR(150)    NOT NULL,
    BANK_ABBR_NM   VARCHAR(90)     NOT NULL,
    BANK_ENG_NM    VARCHAR(150),
    BANK_NAT_CD    CHAR(6),
    RMRK           VARCHAR(12000),
    SORT_NO        INT,
    USE_YN         CHAR(3)         NOT NULL,
    REG_MENU_ID    VARCHAR(300)    NOT NULL,
    REG_ID         VARCHAR(90)     NOT NULL,
    REG_DTTM       TIMESTAMPTZ     NOT NULL,
    MOD_MENU_ID    VARCHAR(300)    NOT NULL,
    MOD_ID         VARCHAR(90)     NOT NULL,
    MOD_DTTM       TIMESTAMPTZ     NOT NULL
);


CREATE TABLE BIDWADM_CO.OD_FI_CMS_BACNT_CNFM_D
(
    BATCH_WRK_SEQ   NUMERIC         NOT NULL,
    SEQ_NO          CHAR(18)        NOT NULL,
    ACUNIT_CD       CHAR(12)        NOT NULL,
    BANK_CD         CHAR(9),
    ACNO            VARCHAR(600),
    CERT_REF_VAL1   VARCHAR(600),
    CERT_REF_VAL2   VARCHAR(600),
    CERT_REF_VAL3   VARCHAR(600),
    MSG_CODE        VARCHAR(60),
    RECV_CODE       VARCHAR(60),
    RECV_DATE       VARCHAR(24),
    RECV_TIME       CHAR(18),
    REG_MENU_ID     VARCHAR(300)    NOT NULL,
    REG_ID          VARCHAR(90)     NOT NULL,
    REG_DTTM        TIMESTAMPTZ     NOT NULL,
    MOD_MENU_ID     VARCHAR(300)    NOT NULL,
    MOD_ID          VARCHAR(90)     NOT NULL,
    MOD_DTTM        TIMESTAMPTZ     NOT NULL
);


CREATE TABLE BIDWADM_CO.OD_FI_CMS_BAL_CNFM_M
(
    ACUNIT_CD    CHAR(12)       NOT NULL,   -- char(4) ×3
    RCV_DT       DATE           NOT NULL,   -- date
    BACNT_CD     CHAR(12)       NOT NULL,   -- char(4) ×3
    CRNCY_CD     CHAR(9),                   -- char(3) ×3
    BAL_AMT      NUMERIC,                   -- precision/scale 미지정 → NUMERIC
    RSP_CD       VARCHAR(30),               -- varchar(10) ×3
    BF_BAL       NUMERIC,                   -- precision/scale 미지정 → NUMERIC
    REG_MENU_ID  VARCHAR(300)   NOT NULL,   -- varchar(100) ×3
    REG_ID       VARCHAR(90)    NOT NULL,   -- varchar(30) ×3
    REG_DTTM     TIMESTAMPTZ    NOT NULL,   -- datetimeoffset → TIMESTAMPTZ
    MOD_MENU_ID  VARCHAR(300)   NOT NULL,   -- varchar(100) ×3
    MOD_ID       VARCHAR(90)    NOT NULL,   -- varchar(30) ×3
    MOD_DTTM     TIMESTAMPTZ    NOT NULL    -- datetimeoffset → TIMESTAMPTZ
);


CREATE TABLE BIDWADM_CO.OD_FI_BANK_DEAL_LDGR_M
(
    BANK_DEAL_SEQ          INT             NOT NULL,
    TRAN_CODE              CHAR(27),
    COMP_CODE              VARCHAR(30),
    BANK_CODE              CHAR(9),
    MSG_CD                 CHAR(12),
    MSG_SE_CD              CHAR(9),
    TRSM_CNT               CHAR(3),
    SEQ_NO                 VARCHAR(30)     NOT NULL,
    TRRC_DT                VARCHAR(30),
    TRRC_HH                CHAR(18),
    RSP_CD                 VARCHAR(30),
    BANK_RSP_CD            VARCHAR(30),
    READ_DT                VARCHAR(30),
    READ_NO                VARCHAR(30),
    BANK_TRXNO             VARCHAR(60),
    CM_REF_1               VARCHAR(150),
    DPST_ACNO              VARCHAR(600)    NOT NULL,
    COMP_CNT               VARCHAR(150),
    CMS_DPWD_SE_CD         CHAR(6),
    CMS_DEAL_SE_CD         CHAR(6),
    DPST_BANK_CD           CHAR(9),
    DPST_AMT               NUMERIC,
    BAL_AMT                NUMERIC,
    FRCR_DPST_AMT          NUMERIC,
    FRCR_BAL_AMT           NUMERIC,
    DPST_BRNC_CD           VARCHAR(150),
    CUST_NAME              VARCHAR(600),
    CHECK_NO               VARCHAR(150),
    CASH_AMT               NUMERIC,
    OCHECK_AMT             NUMERIC,
    ETC_AMT                NUMERIC,
    VRTL_ACNO              VARCHAR(600),
    DEAL_DT                VARCHAR(24)     NOT NULL,
    DEAL_TM                CHAR(18)        NOT NULL,
    DEAL_SRNO              VARCHAR(150),
    INDV_RDF_1             VARCHAR(150),
    ACUNIT_CD              CHAR(12),
    BACNT_CD               CHAR(12),
    CRNCY_CD               CHAR(9),
    EXRT                   NUMERIC,
    CUST_CD                VARCHAR(30),
    SHOP_CD                VARCHAR(30),
    BRND_CD                VARCHAR(30),
    CCTR_CD                VARCHAR(30),
    FDRD_CD                CHAR(15),
    ABST                   VARCHAR(1500),
    SLP_KEY                NUMERIC,
    SLP_LKEY               NUMERIC,
    PRCS_DTTM              TIMESTAMP,
    PRCS_YN                CHAR(3),
    SLP_PRCS_MSG_CNTN      VARCHAR(3000),
    EXCL_YN                CHAR(3),
    EXCL_DTTM              TIMESTAMP,
    EXCL_PRCSR_ID          VARCHAR(90),
    REG_MENU_ID            VARCHAR(300)    NOT NULL,
    REG_ID                 VARCHAR(90)     NOT NULL,
    REG_DTTM               TIMESTAMPTZ     NOT NULL,
    MOD_MENU_ID            VARCHAR(300)    NOT NULL,
    MOD_ID                 VARCHAR(90)     NOT NULL,
    MOD_DTTM               TIMESTAMPTZ     NOT NULL
);




CREATE TABLE BIDWADM_CO.OD_SA_WHLS_ORD_M
(
    COMP_CD                CHAR(12)        NOT NULL,   -- char(4)×3
    BRND_CD                VARCHAR(30)     NOT NULL,   -- varchar(10)×3
    WHLS_ORD_YM            CHAR(18)        NOT NULL,   -- char(6)×3
    WHLS_ORD_TCNT          INT             NOT NULL,
    WHLS_ORD_NO            VARCHAR(150)    NOT NULL,   -- nvarchar(50)×3
    WHLS_ORD_NM            VARCHAR(300)    NOT NULL,   -- nvarchar(100)×3
    CRNCY_CD               CHAR(9),                    -- char(3)×3
    CTGR_CD                VARCHAR(30),                -- varchar(10)×3
    SHOP_CD                VARCHAR(30),                -- varchar(10)×3
    PRCS_STTS_CD           CHAR(3),                    -- char(1)×3
    WHLS_CLS_CD            VARCHAR(30),                -- varchar(10)×3
    WHLS_CUST_ORD_YM       CHAR(18),                   -- char(6)×3
    WHLS_CUST_ORD_TCNT     INT,
    SLSORD_PRGS_STTS_CD    VARCHAR(30),                -- varchar(10)×3
    RMRK                   VARCHAR(12000),             -- nvarchar(4000)×3
    REG_MENU_ID            VARCHAR(300)    NOT NULL,   -- varchar(100)×3
    REG_ID                 VARCHAR(90)     NOT NULL,   -- varchar(30)×3
    REG_DTTM               TIMESTAMPTZ     NOT NULL,   -- datetimeoffset
    MOD_MENU_ID            VARCHAR(300)    NOT NULL,   -- varchar(100)×3
    MOD_ID                 VARCHAR(90)     NOT NULL,   -- varchar(30)×3
    MOD_DTTM               TIMESTAMPTZ     NOT NULL    -- datetimeoffset
);


CREATE TABLE BIDWADM_CO.OD_SA_WHLS_ORD_D
(
    COMP_CD             CHAR(12)        NOT NULL,   -- char(4)×3
    BRND_CD             VARCHAR(30)     NOT NULL,   -- varchar(10)×3
    WHLS_ORD_YM         CHAR(18)        NOT NULL,   -- char(6)×3
    WHLS_ORD_TCNT       INT             NOT NULL,
    WHLS_ORD_NO         VARCHAR(150)    NOT NULL,   -- nvarchar(50)×3
    WHLS_ORD_SN         INT             NOT NULL,
    SMPL_STYL_CD        VARCHAR(90),                -- varchar(30)×3
    SMPL_CLR_CD         VARCHAR(30),                -- varchar(10)×3
    SIZE_CD             VARCHAR(30),                -- varchar(10)×3
    STYL_CD             VARCHAR(60),                -- varchar(20)×3
    CLR_CD              VARCHAR(30),                -- varchar(10)×3
    REQ_QTY             NUMERIC         NOT NULL,   -- precision/scale 미표기 → NUMERIC
    WHLS_TP_CD          VARCHAR(30),                -- varchar(10)×3
    WHLS_SE_CD          VARCHAR(30),                -- varchar(10)×3
    IN_REQ_DT           DATE,
    PACK_SE_CD          VARCHAR(30),                -- varchar(10)×3
    PO_YM               CHAR(18),                   -- char(6)×3
    PO_NO               VARCHAR(90),                -- varchar(30)×3
    PROD_TCNT           INT,
    RMRK                VARCHAR(12000),             -- nvarchar(4000)×3
    REG_MENU_ID         VARCHAR(300)    NOT NULL,   -- varchar(100)×3
    REG_ID              VARCHAR(90)     NOT NULL,   -- varchar(30)×3
    REG_DTTM            TIMESTAMPTZ     NOT NULL,   -- datetimeoffset → TIMESTAMPTZ
    MOD_MENU_ID         VARCHAR(300)    NOT NULL,   -- varchar(100)×3
    MOD_ID              VARCHAR(90)     NOT NULL,   -- varchar(30)×3
    MOD_DTTM            TIMESTAMPTZ     NOT NULL    -- datetimeoffset → TIMESTAMPTZ
);

