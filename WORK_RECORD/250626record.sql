
------------------------------------------------------------------------------------------------SR00001695_컬럼추가 START
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

USE ERP
GO


EXEC PR_DBA_RECREATE EI_IMPO_INSR_M 
GO



 IF OBJECT_ID('[dbo].[EI_IMPO_INSR_M]') IS NOT NULL 
 DROP TABLE [dbo].[EI_IMPO_INSR_M] 
 GO
 CREATE TABLE [dbo].[EI_IMPO_INSR_M] ( 
 [COMP_CD]                 CHAR(4)                                 NOT NULL,
 [INVC_NO]                 NVARCHAR(20)                            NOT NULL,
 [IMPO_INSR_SN]            INT                                     NOT NULL,
 [IMPO_PO_YR]              CHAR(4)                                     NULL,
 [IMPO_PO_NO]              VARCHAR(30)                                 NULL,
 [INSR_CUST_CD]            VARCHAR(10)                                 NULL,
 [ACUNIT_CD]               CHAR(4)                                     NULL,
 [INSR_NO]                 NVARCHAR(50)                                NULL,
 [KRW_INSR_TAMT]           NUMERIC(20,4)                               NULL,
 [USD_INSR_TAMT]           NUMERIC(20,4)                               NULL,
 [INSR_JOIN_PRGS_STTS_CD]  VARCHAR(10)                                 NULL,
 [MAIN_KEY]                VARCHAR(50)                                 NULL,
 [INSR_STRT_DT]            DATE                                        NULL,
 [HS_CD]                   VARCHAR(2000)                               NULL,
 [INVC_AMT]                NUMERIC(20,4)                               NULL,
 [INVC_AMT_CRNCY_CD]       CHAR(3)                                     NULL,
 [PCKG_CNT]                INT                                         NULL,
 [PCKG_UNIT_CD]            VARCHAR(2)                                  NULL,
 [CPHS_INSR_NO]            NVARCHAR(50)                                NULL,
 [BIZR_NM]                 NVARCHAR(100)                               NULL,
 [BRNO]                    VARCHAR(50)                                 NULL,
 [RPRSR_NM]                NVARCHAR(50)                                NULL,
 [COPY_ISS_REQ_QTY]        NUMERIC(15,0)                               NULL,
 [ORG_ISS_REQ_QTY]         NUMERIC(15,0)                               NULL,
 [WISH_PFT_RT]             NUMERIC(5,2)                                NULL,
 [BSC_COND_CD]             VARCHAR(5)                                  NULL,
 [BSC_COND_NM]             NVARCHAR(100)                               NULL,
 [GDS_EXPN]                NVARCHAR(4000)                              NULL,
 [SHIP_NM]                 NVARCHAR(100)                               NULL,
 [PTOT_DT]                 DATE                                        NULL,
 [SHPP_NAT_CD]             CHAR(2)                                     NULL,
 [SHPP_RGN_NM]             NVARCHAR(100)                               NULL,
 [ARR_NAT_CD]              CHAR(2)                                     NULL,
 [ARR_RGN_NM]              NVARCHAR(100)                               NULL,
 [FNL_DEST_NAT_CD]         CHAR(2)                                     NULL,
 [FNL_DEST_RGN_NM]         NVARCHAR(100)                               NULL,
 [TRSHPT_NAT_CD]           CHAR(2)                                     NULL,
 [TRSHPT_RGN_NM]           NVARCHAR(100)                               NULL,
 [JNT_TKOV_COMP_CD]        VARCHAR(5)                                  NULL,
 [JNT_TKOV_RT]             NUMERIC(5,2)                                NULL,
 [INSR_SECS_FILE_GRP_NO]   INT                                         NULL,
 [INSR_SECS_FILE_SN]       INT                                         NULL,
 [DEL_YN]                  CHAR(1)                                 NOT NULL  CONSTRAINT [EI_IMPO_INSR_M_DEL_YN_DFLT] DEFAULT ('N'),
 [EML_ADDR]                NVARCHAR(100)                               NULL,
 [EML_SEND_STTS_CD]        CHAR(2)                                     NULL,
 [EML_SEND_DT]             DATE                                        NULL,
 [EML_SEND_YN]             CHAR(1)                                     NULL,
 [REG_MENU_ID]             VARCHAR(100)                            NOT NULL,
 [REG_ID]                  VARCHAR(30)                             NOT NULL,
 [REG_DTTM]                DATETIMEOFFSET                          NOT NULL  CONSTRAINT [EI_IMPO_INSR_M_REG_DTTM_DFLT] DEFAULT (sysdatetimeoffset()),
 [MOD_MENU_ID]             VARCHAR(100)                            NOT NULL,
 [MOD_ID]                  VARCHAR(30)                             NOT NULL,
 [MOD_DTTM]                DATETIMEOFFSET                          NOT NULL  CONSTRAINT [EI_IMPO_INSR_M_MOD_DTTM_DFLT] DEFAULT (sysdatetimeoffset()),
 CONSTRAINT   [PK_EI_IMPO_INSR_M]  PRIMARY KEY CLUSTERED    ([COMP_CD] asc, [INVC_NO] asc, [IMPO_INSR_SN] asc) )
 
 GO
 
 EXEC sys.sp_addextendedproperty
          @name = N'MS_Description', @value = N'수입보험',
          @level0type = N'SCHEMA', @level0name = [dbo],
          @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'회사코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [COMP_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'송장번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INVC_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수입보험순번',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [IMPO_INSR_SN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수입발주년도',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [IMPO_PO_YR];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수입발주번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [IMPO_PO_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'보험거래처코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INSR_CUST_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'회계단위코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [ACUNIT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'보험번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INSR_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'원화보험총금액',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [KRW_INSR_TAMT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'달러보험총금액',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [USD_INSR_TAMT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'보험가입진행상태코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INSR_JOIN_PRGS_STTS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'메인KEY',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [MAIN_KEY];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'보험시작일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INSR_STRT_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'HS코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [HS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'송장금액',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INVC_AMT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'송장금액통화코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INVC_AMT_CRNCY_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'포장건수',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [PCKG_CNT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'포장단위코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [PCKG_UNIT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'포괄보험번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [CPHS_INSR_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'사업자명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [BIZR_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'사업자등록번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [BRNO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'대표자명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [RPRSR_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'복사발급요청수량',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [COPY_ISS_REQ_QTY];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'원본발급요청수량',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [ORG_ISS_REQ_QTY];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'희망이익비율',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [WISH_PFT_RT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'기본조건코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [BSC_COND_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'기본조건명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [BSC_COND_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'상품설명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [GDS_EXPN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선박명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [SHIP_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'출항일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [PTOT_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적국가코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [SHPP_NAT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적지역명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [SHPP_RGN_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'도착국가코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [ARR_NAT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'도착지역명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [ARR_RGN_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'최종목적지국가코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [FNL_DEST_NAT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'최종목적지지역명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [FNL_DEST_RGN_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'환적국가코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [TRSHPT_NAT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'환적지역명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [TRSHPT_RGN_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'공동인수회사코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [JNT_TKOV_COMP_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'공동인수비율',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [JNT_TKOV_RT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'보험증권파일그룹번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INSR_SECS_FILE_GRP_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'보험증권파일순번',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [INSR_SECS_FILE_SN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'삭제여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [DEL_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'이메일주소',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [EML_ADDR];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'이메일발송상태코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [EML_SEND_STTS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'이메일발송일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [EML_SEND_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'이메일발송여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [EML_SEND_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록메뉴ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [REG_MENU_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [REG_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록일시',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [REG_DTTM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정메뉴ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [MOD_MENU_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [MOD_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정일시',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_INSR_M],
         @level2type = N'COLUMN', @level2name = [MOD_DTTM];

-- SOURCE TABLE 데이터 백업(완료)
-- 백업 테이블명: ZZ_EI_IMPO_INSR_M_20250626
-- 백업 건수 확인
SELECT COUNT(*) FROM ZZ_EI_IMPO_INSR_M_20250626
-- Copied Rows : 23 Rows

-- 권한 복구
USE ERP; GRANT DELETE ON dbo.EI_IMPO_INSR_M TO RL_RW_SCM;
USE ERP; GRANT INSERT ON dbo.EI_IMPO_INSR_M TO RL_RW_SCM;
USE ERP; GRANT UPDATE ON dbo.EI_IMPO_INSR_M TO RL_RW_SCM;
GO

-- 데이터 복구
PR_DBA_RESTORE ZZ_EI_IMPO_INSR_M_20250626, EI_IMPO_INSR_M
GO

-- 복구 후 원본 테이블 건수 확인
SELECT COUNT(*) FROM EI_IMPO_INSR_M
GO


CREATE STATISTICS IMPO_PO_YR ON EI_IMPO_INSR_M(IMPO_PO_YR)
GO
CREATE STATISTICS IMPO_PO_NO ON EI_IMPO_INSR_M(IMPO_PO_NO)
GO
CREATE STATISTICS INSR_CUST_CD ON EI_IMPO_INSR_M(INSR_CUST_CD)
GO
CREATE STATISTICS ACUNIT_CD ON EI_IMPO_INSR_M(ACUNIT_CD)
GO
CREATE STATISTICS INSR_NO ON EI_IMPO_INSR_M(INSR_NO)
GO
CREATE STATISTICS KRW_INSR_TAMT ON EI_IMPO_INSR_M(KRW_INSR_TAMT)
GO
CREATE STATISTICS USD_INSR_TAMT ON EI_IMPO_INSR_M(USD_INSR_TAMT)
GO
CREATE STATISTICS INSR_JOIN_PRGS_STTS_CD ON EI_IMPO_INSR_M(INSR_JOIN_PRGS_STTS_CD)
GO
CREATE STATISTICS MAIN_KEY ON EI_IMPO_INSR_M(MAIN_KEY)
GO
CREATE STATISTICS INSR_STRT_DT ON EI_IMPO_INSR_M(INSR_STRT_DT)
GO
CREATE STATISTICS HS_CD ON EI_IMPO_INSR_M(HS_CD)
GO
CREATE STATISTICS INVC_AMT ON EI_IMPO_INSR_M(INVC_AMT)
GO
CREATE STATISTICS INVC_AMT_CRNCY_CD ON EI_IMPO_INSR_M(INVC_AMT_CRNCY_CD)
GO
CREATE STATISTICS PCKG_CNT ON EI_IMPO_INSR_M(PCKG_CNT)
GO
CREATE STATISTICS PCKG_UNIT_CD ON EI_IMPO_INSR_M(PCKG_UNIT_CD)
GO
CREATE STATISTICS CPHS_INSR_NO ON EI_IMPO_INSR_M(CPHS_INSR_NO)
GO
CREATE STATISTICS BIZR_NM ON EI_IMPO_INSR_M(BIZR_NM)
GO
CREATE STATISTICS BRNO ON EI_IMPO_INSR_M(BRNO)
GO
CREATE STATISTICS RPRSR_NM ON EI_IMPO_INSR_M(RPRSR_NM)
GO
CREATE STATISTICS COPY_ISS_REQ_QTY ON EI_IMPO_INSR_M(COPY_ISS_REQ_QTY)
GO
CREATE STATISTICS ORG_ISS_REQ_QTY ON EI_IMPO_INSR_M(ORG_ISS_REQ_QTY)
GO
CREATE STATISTICS WISH_PFT_RT ON EI_IMPO_INSR_M(WISH_PFT_RT)
GO
CREATE STATISTICS BSC_COND_CD ON EI_IMPO_INSR_M(BSC_COND_CD)
GO
CREATE STATISTICS BSC_COND_NM ON EI_IMPO_INSR_M(BSC_COND_NM)
GO
CREATE STATISTICS GDS_EXPN ON EI_IMPO_INSR_M(GDS_EXPN)
GO
CREATE STATISTICS SHIP_NM ON EI_IMPO_INSR_M(SHIP_NM)
GO
CREATE STATISTICS PTOT_DT ON EI_IMPO_INSR_M(PTOT_DT)
GO
CREATE STATISTICS SHPP_NAT_CD ON EI_IMPO_INSR_M(SHPP_NAT_CD)
GO
CREATE STATISTICS SHPP_RGN_NM ON EI_IMPO_INSR_M(SHPP_RGN_NM)
GO
CREATE STATISTICS ARR_NAT_CD ON EI_IMPO_INSR_M(ARR_NAT_CD)
GO
CREATE STATISTICS ARR_RGN_NM ON EI_IMPO_INSR_M(ARR_RGN_NM)
GO
CREATE STATISTICS FNL_DEST_NAT_CD ON EI_IMPO_INSR_M(FNL_DEST_NAT_CD)
GO
CREATE STATISTICS FNL_DEST_RGN_NM ON EI_IMPO_INSR_M(FNL_DEST_RGN_NM)
GO
CREATE STATISTICS TRSHPT_NAT_CD ON EI_IMPO_INSR_M(TRSHPT_NAT_CD)
GO
CREATE STATISTICS TRSHPT_RGN_NM ON EI_IMPO_INSR_M(TRSHPT_RGN_NM)
GO
CREATE STATISTICS JNT_TKOV_COMP_CD ON EI_IMPO_INSR_M(JNT_TKOV_COMP_CD)
GO
CREATE STATISTICS JNT_TKOV_RT ON EI_IMPO_INSR_M(JNT_TKOV_RT)
GO
CREATE STATISTICS INSR_SECS_FILE_GRP_NO ON EI_IMPO_INSR_M(INSR_SECS_FILE_GRP_NO)
GO
CREATE STATISTICS INSR_SECS_FILE_SN ON EI_IMPO_INSR_M(INSR_SECS_FILE_SN)
GO
CREATE STATISTICS DEL_YN ON EI_IMPO_INSR_M(DEL_YN)
GO
CREATE STATISTICS EML_ADDR ON EI_IMPO_INSR_M(EML_ADDR)
GO
CREATE STATISTICS EML_SEND_STTS_CD ON EI_IMPO_INSR_M(EML_SEND_STTS_CD)
GO
CREATE STATISTICS EML_SEND_DT ON EI_IMPO_INSR_M(EML_SEND_DT)
GO
CREATE STATISTICS EML_SEND_YN ON EI_IMPO_INSR_M(EML_SEND_YN)
GO
CREATE STATISTICS REG_MENU_ID ON EI_IMPO_INSR_M(REG_MENU_ID)
GO
CREATE STATISTICS REG_ID ON EI_IMPO_INSR_M(REG_ID)
GO
CREATE STATISTICS REG_DTTM ON EI_IMPO_INSR_M(REG_DTTM)
GO
CREATE STATISTICS MOD_MENU_ID ON EI_IMPO_INSR_M(MOD_MENU_ID)
GO
CREATE STATISTICS MOD_ID ON EI_IMPO_INSR_M(MOD_ID)
GO
CREATE STATISTICS MOD_DTTM ON EI_IMPO_INSR_M(MOD_DTTM)
GO

-- 통계 확인
EXEC SP_DBA_MAKE_STATS ERP, EI_IMPO_INSR_M



--EI_IMPO_CCLR_M

EXEC PR_DBA_RECREATE EI_IMPO_CCLR_M




 IF OBJECT_ID('[dbo].[EI_IMPO_CCLR_M]') IS NOT NULL 
 DROP TABLE [dbo].[EI_IMPO_CCLR_M] 
 GO
 CREATE TABLE [dbo].[EI_IMPO_CCLR_M] ( 
 [COMP_CD]            CHAR(4)                                 NOT NULL,
 [BL_MNG_YM]          CHAR(6)                                 NOT NULL,
 [BL_MNG_NO]          NVARCHAR(20)                            NOT NULL,
 [IMPO_CCLR_REG_SN]   INT                                     NOT NULL,
 [ACUNIT_CD]          CHAR(4)                                     NULL,
 [BKNG_NO]            NVARCHAR(100)                               NULL,
 [DIMPO_YN]           CHAR(1)                                     NULL  CONSTRAINT [EI_IMPO_CCLR_M_DIMPO_YN_DFLT] DEFAULT ('N'),
 [CCLR_PRGS_STTS_CD]  VARCHAR(10)                                 NULL,
 [DCLR_NO]            NVARCHAR(20)                                NULL,
 [DCLR_DT]            DATE                                        NULL,
 [CCLR_CMPL_DT]       DATE                                        NULL,
 [OPNN_CNTN]          NVARCHAR(2000)                              NULL,
 [REQ_DT]             DATE                                        NULL,
 [CSAG_PIC_ID]        VARCHAR(30)                                 NULL,
 [ADD_PIC_LIST]       NVARCHAR(1000)                              NULL,
 [RCVR_NM]            NVARCHAR(50)                                NULL,
 [RCVR_TELNO]         VARCHAR(30)                                 NULL,
 [RCVR_FAXNO]         VARCHAR(20)                                 NULL,
 [SNDR_NM]            NVARCHAR(200)                               NULL,
 [SNDR_TELNO]         VARCHAR(30)                                 NULL,
 [SNDR_FAXNO]         VARCHAR(20)                                 NULL,
 [IMPO_IN_ADDR]       NVARCHAR(500)                               NULL,
 [IMPO_IN_PIC_NM]     NVARCHAR(100)                               NULL,
 [EML_SEND_STTS_CD]   CHAR(2)                                     NULL,
 [EML_SEND_DT]        DATE                                        NULL,
 [EML_SEND_YN]        CHAR(1)                                     NULL,
 [DEL_YN]             CHAR(1)                                 NOT NULL  CONSTRAINT [EI_IMPO_CCLR_M_DEL_YN_DFLT] DEFAULT ('N'),
 [REG_MENU_ID]        VARCHAR(100)                            NOT NULL,
 [REG_ID]             VARCHAR(30)                             NOT NULL,
 [REG_DTTM]           DATETIMEOFFSET                          NOT NULL  CONSTRAINT [EI_IMPO_CCLR_M_REG_DTTM_DFLT] DEFAULT (sysdatetimeoffset()),
 [MOD_MENU_ID]        VARCHAR(100)                            NOT NULL,
 [MOD_ID]             VARCHAR(30)                             NOT NULL,
 [MOD_DTTM]           DATETIMEOFFSET                          NOT NULL  CONSTRAINT [EI_IMPO_CCLR_M_MOD_DTTM_DFLT] DEFAULT (sysdatetimeoffset()),
 CONSTRAINT   [PK_EI_IMPO_CCLR_M]  PRIMARY KEY CLUSTERED    ([COMP_CD] asc, [BL_MNG_YM] asc, [BL_MNG_NO] asc, [IMPO_CCLR_REG_SN] asc) )
 
 GO
 
 EXEC sys.sp_addextendedproperty
          @name = N'MS_Description', @value = N'수입통관',
          @level0type = N'SCHEMA', @level0name = [dbo],
          @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'회사코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [COMP_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'BL관리년월',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [BL_MNG_YM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'BL관리번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [BL_MNG_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수입통관등록순번',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [IMPO_CCLR_REG_SN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'회계단위코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [ACUNIT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'부킹번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [BKNG_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'직수입여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [DIMPO_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'통관진행상태코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [CCLR_PRGS_STTS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'신고번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [DCLR_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'신고일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [DCLR_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'통관완료일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [CCLR_CMPL_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'의견내용',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [OPNN_CNTN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'요청일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [REQ_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'관세사담당자ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [CSAG_PIC_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'추가담당자목록',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [ADD_PIC_LIST];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수신자명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [RCVR_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수신자전화번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [RCVR_TELNO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수신자팩스번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [RCVR_FAXNO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'발신자명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [SNDR_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'발신자전화번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [SNDR_TELNO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'발신자팩스번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [SNDR_FAXNO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수입입고주소',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [IMPO_IN_ADDR];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수입입고담당자명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [IMPO_IN_PIC_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'이메일발송상태코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [EML_SEND_STTS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'이메일발송일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [EML_SEND_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'이메일발송여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [EML_SEND_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'삭제여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [DEL_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록메뉴ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [REG_MENU_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [REG_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록일시',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [REG_DTTM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정메뉴ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [MOD_MENU_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [MOD_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정일시',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_IMPO_CCLR_M],
         @level2type = N'COLUMN', @level2name = [MOD_DTTM];


-- SOURCE TABLE 데이터 백업(완료)
-- 백업 테이블명: ZZ_EI_IMPO_CCLR_M_20250626
-- 백업 건수 확인
SELECT COUNT(*) FROM ZZ_EI_IMPO_CCLR_M_20250626
-- Copied Rows : 46 Rows

-- 권한 복구
USE ERP; GRANT DELETE ON dbo.EI_IMPO_CCLR_M TO RL_RW_SCM;
USE ERP; GRANT INSERT ON dbo.EI_IMPO_CCLR_M TO RL_RW_SCM;
USE ERP; GRANT UPDATE ON dbo.EI_IMPO_CCLR_M TO RL_RW_SCM;
GO

-- 데이터 복구
PR_DBA_RESTORE ZZ_EI_IMPO_CCLR_M_20250626, EI_IMPO_CCLR_M
GO

-- 복구 후 원본 테이블 건수 확인
SELECT COUNT(*) FROM EI_IMPO_CCLR_M
GO


CREATE STATISTICS ACUNIT_CD ON EI_IMPO_CCLR_M(ACUNIT_CD)
GO
CREATE STATISTICS BKNG_NO ON EI_IMPO_CCLR_M(BKNG_NO)
GO
CREATE STATISTICS DIMPO_YN ON EI_IMPO_CCLR_M(DIMPO_YN)
GO
CREATE STATISTICS CCLR_PRGS_STTS_CD ON EI_IMPO_CCLR_M(CCLR_PRGS_STTS_CD)
GO
CREATE STATISTICS DCLR_NO ON EI_IMPO_CCLR_M(DCLR_NO)
GO
CREATE STATISTICS DCLR_DT ON EI_IMPO_CCLR_M(DCLR_DT)
GO
CREATE STATISTICS CCLR_CMPL_DT ON EI_IMPO_CCLR_M(CCLR_CMPL_DT)
GO
CREATE STATISTICS OPNN_CNTN ON EI_IMPO_CCLR_M(OPNN_CNTN)
GO
CREATE STATISTICS REQ_DT ON EI_IMPO_CCLR_M(REQ_DT)
GO
CREATE STATISTICS CSAG_PIC_ID ON EI_IMPO_CCLR_M(CSAG_PIC_ID)
GO
CREATE STATISTICS ADD_PIC_LIST ON EI_IMPO_CCLR_M(ADD_PIC_LIST)
GO
CREATE STATISTICS RCVR_NM ON EI_IMPO_CCLR_M(RCVR_NM)
GO
CREATE STATISTICS RCVR_TELNO ON EI_IMPO_CCLR_M(RCVR_TELNO)
GO
CREATE STATISTICS RCVR_FAXNO ON EI_IMPO_CCLR_M(RCVR_FAXNO)
GO
CREATE STATISTICS SNDR_NM ON EI_IMPO_CCLR_M(SNDR_NM)
GO
CREATE STATISTICS SNDR_TELNO ON EI_IMPO_CCLR_M(SNDR_TELNO)
GO
CREATE STATISTICS SNDR_FAXNO ON EI_IMPO_CCLR_M(SNDR_FAXNO)
GO
CREATE STATISTICS IMPO_IN_ADDR ON EI_IMPO_CCLR_M(IMPO_IN_ADDR)
GO
CREATE STATISTICS IMPO_IN_PIC_NM ON EI_IMPO_CCLR_M(IMPO_IN_PIC_NM)
GO
CREATE STATISTICS EML_SEND_STTS_CD ON EI_IMPO_CCLR_M(EML_SEND_STTS_CD)
GO
CREATE STATISTICS EML_SEND_DT ON EI_IMPO_CCLR_M(EML_SEND_DT)
GO
CREATE STATISTICS EML_SEND_YN ON EI_IMPO_CCLR_M(EML_SEND_YN)
GO
CREATE STATISTICS DEL_YN ON EI_IMPO_CCLR_M(DEL_YN)
GO
CREATE STATISTICS REG_MENU_ID ON EI_IMPO_CCLR_M(REG_MENU_ID)
GO
CREATE STATISTICS REG_ID ON EI_IMPO_CCLR_M(REG_ID)
GO
CREATE STATISTICS REG_DTTM ON EI_IMPO_CCLR_M(REG_DTTM)
GO
CREATE STATISTICS MOD_MENU_ID ON EI_IMPO_CCLR_M(MOD_MENU_ID)
GO
CREATE STATISTICS MOD_ID ON EI_IMPO_CCLR_M(MOD_ID)
GO
CREATE STATISTICS MOD_DTTM ON EI_IMPO_CCLR_M(MOD_DTTM)
GO

-- 통계 확인
EXEC SP_DBA_MAKE_STATS ERP, EI_IMPO_CCLR_M



--EI_EXPO_SHPP_M


EXEC PR_DBA_RECREATE EI_EXPO_SHPP_M



 IF OBJECT_ID('[dbo].[EI_EXPO_SHPP_M]') IS NOT NULL 
 DROP TABLE [dbo].[EI_EXPO_SHPP_M] 
 GO
 CREATE TABLE [dbo].[EI_EXPO_SHPP_M] ( 
 [COMP_CD]                    CHAR(4)                                 NOT NULL,
 [BL_MNG_YM]                  CHAR(6)                                 NOT NULL,
 [BL_MNG_NO]                  NVARCHAR(20)                            NOT NULL,
 [ACUNIT_CD]                  CHAR(4)                                     NULL,
 [INVC_NO1]                   NVARCHAR(20)                                NULL,
 [INVC_NO2]                   NVARCHAR(20)                                NULL,
 [BKNG_NO]                    NVARCHAR(100)                               NULL,
 [BL_NO]                      NVARCHAR(100)                               NULL,
 [EXPO_DCLR_CERT_NO]          NVARCHAR(50)                                NULL,
 [PAY_COND_CD]                VARCHAR(10)                                 NULL,
 [CUST_CD]                    VARCHAR(10)                                 NULL,
 [CUST_NM]                    NVARCHAR(100)                               NULL,
 [CUST_COMP_CD]               CHAR(4)                                     NULL,
 [CRNCY_CD]                   CHAR(3)                                     NULL,
 [EXPO_NAT_CD]                CHAR(2)                                     NULL,
 [TRPT_MTHD_CD]               VARCHAR(10)                                 NULL,
 [POL_NM]                     NVARCHAR(200)                               NULL,
 [POL_CD]                     VARCHAR(10)                                 NULL,
 [POD_NM]                     NVARCHAR(200)                               NULL,
 [POD_CD]                     VARCHAR(10)                                 NULL,
 [SHIP_AVTN_NO]               NVARCHAR(100)                               NULL,
 [SHPP_DT]                    DATE                                        NULL,
 [SHPP_CMPL_YN]               CHAR(1)                                     NULL,
 [SHPP_CMPL_DT]               DATE                                        NULL,
 [PBLT_DT]                    DATE                                        NULL,
 [ARR_SCH_DT]                 DATE                                        NULL,
 [EXRT]                       NUMERIC(12,6)                               NULL,
 [WRHS_CD]                    CHAR(4)                                     NULL,
 [SHOP_CD]                    VARCHAR(10)                                 NULL,
 [SLP_OCRN_SN]                INT                                         NULL,
 [SL_RCPT_NO]                 NVARCHAR(50)                                NULL,
 [SL_RCPT_SN]                 INT                                         NULL,
 [SL_DT]                      DATE                                        NULL,
 [CT_INFO_EXCL_YN]            CHAR(1)                                     NULL,
 [ATRZ_USE_YN]                CHAR(1)                                     NULL,
 [SHPP_PPRS_RVW_EXCL_YN]      CHAR(1)                                     NULL,
 [PDITEM_SE_CD]               VARCHAR(10)                                 NULL,
 [RVW_STTS_CD]                VARCHAR(10)                                 NULL,
 [SHPP_PPRS_CHG_YN]           CHAR(1)                                     NULL,
 [SHPP_PPRS_CHG_DT]           DATE                                        NULL,
 [SHPP_PPRS_RVW_APRV_DT]      DATE                                        NULL,
 [INLD_TCOST]                 NUMERIC(20,4)                               NULL,
 [INLD_COST_INVC_NO]          NVARCHAR(20)                                NULL,
 [ACTL_DEP_DT]                DATE                                        NULL,
 [ACTL_ARR_DT]                DATE                                        NULL,
 [FWDR_NM]                    NVARCHAR(200)                               NULL,
 [RVW_OPNN_CNTN]              NVARCHAR(2000)                              NULL,
 [MST_BL_NO]                  NVARCHAR(20)                                NULL,
 [SHPCO_CD]                   VARCHAR(10)                                 NULL,
 [SHPCO_NM]                   NVARCHAR(100)                               NULL,
 [CTNR_TRKG_YN]               CHAR(1)                                     NULL,
 [SHIP_TRKG_STTS_CD]          VARCHAR(10)                                 NULL,
 [CCO_MNG_NO]                 NVARCHAR(100)                               NULL,
 [SHPP_PPRS_VER_VAL]          INT                                         NULL,
 [FCT_SHPP_PPRS_RVW_STTS_CD]  VARCHAR(10)                                 NULL,
 [EML_ADDR]                   NVARCHAR(100)                               NULL,
 [DEL_YN]                     CHAR(1)                                 NOT NULL  CONSTRAINT [EI_EXPO_SHPP_M_DEL_YN_DFLT] DEFAULT ('N'),
 [ATCH_FILE_GRP_NO]           INT                                         NULL,
 [REG_MENU_ID]                VARCHAR(100)                            NOT NULL,
 [REG_ID]                     VARCHAR(30)                             NOT NULL,
 [REG_DTTM]                   DATETIMEOFFSET                          NOT NULL  CONSTRAINT [EI_EXPO_SHPP_M_REG_DTTM_DFLT] DEFAULT (sysdatetimeoffset()),
 [MOD_MENU_ID]                VARCHAR(100)                            NOT NULL,
 [MOD_ID]                     VARCHAR(30)                             NOT NULL,
 [MOD_DTTM]                   DATETIMEOFFSET                          NOT NULL  CONSTRAINT [EI_EXPO_SHPP_M_MOD_DTTM_DFLT] DEFAULT (sysdatetimeoffset()),
 CONSTRAINT   [PK_EI_EXPO_SHPP_M]  PRIMARY KEY CLUSTERED    ([COMP_CD] asc, [BL_MNG_YM] asc, [BL_MNG_NO] asc) )
 
 GO
 
 
 EXEC sys.sp_addextendedproperty
          @name = N'MS_Description', @value = N'수출선적',
          @level0type = N'SCHEMA', @level0name = [dbo],
          @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'회사코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [COMP_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'BL관리년월',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [BL_MNG_YM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'BL관리번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [BL_MNG_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'회계단위코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [ACUNIT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'송장번호1',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [INVC_NO1];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'송장번호2',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [INVC_NO2];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'부킹번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [BKNG_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'BL번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [BL_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수출신고인증번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [EXPO_DCLR_CERT_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'결제조건코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [PAY_COND_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'거래처코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [CUST_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'거래처명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [CUST_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'거래처회사코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [CUST_COMP_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'통화코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [CRNCY_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수출국가코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [EXPO_NAT_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'운송방법코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [TRPT_MTHD_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적항명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [POL_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적항코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [POL_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'도착항명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [POD_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'도착항코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [POD_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선박항공번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHIP_AVTN_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPP_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적완료여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPP_CMPL_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적완료일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPP_CMPL_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'발행일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [PBLT_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'도착예정일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [ARR_SCH_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'환율',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [EXRT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'창고코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [WRHS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'매장코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHOP_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'전표발생순번',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SLP_OCRN_SN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'판매영수증번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SL_RCPT_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'판매영수증순번',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SL_RCPT_SN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'판매일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SL_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'카톤정보제외여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [CT_INFO_EXCL_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'결재사용여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [ATRZ_USE_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적서류검토제외여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPP_PPRS_RVW_EXCL_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'품목구분코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [PDITEM_SE_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'검토상태코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [RVW_STTS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적서류변경여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPP_PPRS_CHG_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적서류변경일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPP_PPRS_CHG_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적서류검토승인일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPP_PPRS_RVW_APRV_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'내륙총비용',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [INLD_TCOST];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'내륙비용송장번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [INLD_COST_INVC_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'실제출발일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [ACTL_DEP_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'실제도착일자',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [ACTL_ARR_DT];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'포워더명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [FWDR_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'검토의견내용',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [RVW_OPNN_CNTN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'마스터BL번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [MST_BL_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선사코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPCO_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선사명',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPCO_NM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'컨테이너추적여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [CTNR_TRKG_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선박추적상태코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHIP_TRKG_STTS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'고객사관리번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [CCO_MNG_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'선적서류버전값',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [SHPP_PPRS_VER_VAL];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'공장선적서류검토상태코드',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [FCT_SHPP_PPRS_RVW_STTS_CD];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'이메일주소',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [EML_ADDR];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'삭제여부',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [DEL_YN];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'첨부파일그룹번호',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [ATCH_FILE_GRP_NO];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록메뉴ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [REG_MENU_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [REG_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'등록일시',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [REG_DTTM];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정메뉴ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [MOD_MENU_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정ID',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [MOD_ID];
 
 EXEC sys.sp_addextendedproperty
         @name = N'MS_Description', @value = N'수정일시',
         @level0type = N'SCHEMA', @level0name = [dbo],
         @level1type = N'TABLE', @level1name = [EI_EXPO_SHPP_M],
         @level2type = N'COLUMN', @level2name = [MOD_DTTM];

-- SOURCE TABLE 데이터 백업(완료)
-- 백업 테이블명: ZZ_EI_EXPO_SHPP_M_20250626
-- 백업 건수 확인
SELECT COUNT(*) FROM ZZ_EI_EXPO_SHPP_M_20250626
-- Copied Rows : 1060 Rows

-- 권한 복구
USE ERP; GRANT DELETE ON dbo.EI_EXPO_SHPP_M TO RL_RW_SCM;
USE ERP; GRANT INSERT ON dbo.EI_EXPO_SHPP_M TO RL_RW_SCM;
USE ERP; GRANT UPDATE ON dbo.EI_EXPO_SHPP_M TO RL_RW_SCM;
GO

-- 데이터 복구
PR_DBA_RESTORE ZZ_EI_EXPO_SHPP_M_20250626, EI_EXPO_SHPP_M
GO

-- 복구 후 원본 테이블 건수 확인
SELECT COUNT(*) FROM EI_EXPO_SHPP_M
GO



CREATE STATISTICS ACUNIT_CD ON EI_EXPO_SHPP_M(ACUNIT_CD)
GO
CREATE STATISTICS INVC_NO1 ON EI_EXPO_SHPP_M(INVC_NO1)
GO
CREATE STATISTICS INVC_NO2 ON EI_EXPO_SHPP_M(INVC_NO2)
GO
CREATE STATISTICS BKNG_NO ON EI_EXPO_SHPP_M(BKNG_NO)
GO
CREATE STATISTICS BL_NO ON EI_EXPO_SHPP_M(BL_NO)
GO
CREATE STATISTICS EXPO_DCLR_CERT_NO ON EI_EXPO_SHPP_M(EXPO_DCLR_CERT_NO)
GO
CREATE STATISTICS PAY_COND_CD ON EI_EXPO_SHPP_M(PAY_COND_CD)
GO
CREATE STATISTICS CUST_CD ON EI_EXPO_SHPP_M(CUST_CD)
GO
CREATE STATISTICS CUST_NM ON EI_EXPO_SHPP_M(CUST_NM)
GO
CREATE STATISTICS CUST_COMP_CD ON EI_EXPO_SHPP_M(CUST_COMP_CD)
GO
CREATE STATISTICS CRNCY_CD ON EI_EXPO_SHPP_M(CRNCY_CD)
GO
CREATE STATISTICS EXPO_NAT_CD ON EI_EXPO_SHPP_M(EXPO_NAT_CD)
GO
CREATE STATISTICS TRPT_MTHD_CD ON EI_EXPO_SHPP_M(TRPT_MTHD_CD)
GO
CREATE STATISTICS POL_NM ON EI_EXPO_SHPP_M(POL_NM)
GO
CREATE STATISTICS POL_CD ON EI_EXPO_SHPP_M(POL_CD)
GO
CREATE STATISTICS POD_NM ON EI_EXPO_SHPP_M(POD_NM)
GO
CREATE STATISTICS POD_CD ON EI_EXPO_SHPP_M(POD_CD)
GO
CREATE STATISTICS SHIP_AVTN_NO ON EI_EXPO_SHPP_M(SHIP_AVTN_NO)
GO
CREATE STATISTICS SHPP_DT ON EI_EXPO_SHPP_M(SHPP_DT)
GO
CREATE STATISTICS SHPP_CMPL_YN ON EI_EXPO_SHPP_M(SHPP_CMPL_YN)
GO
CREATE STATISTICS SHPP_CMPL_DT ON EI_EXPO_SHPP_M(SHPP_CMPL_DT)
GO
CREATE STATISTICS PBLT_DT ON EI_EXPO_SHPP_M(PBLT_DT)
GO
CREATE STATISTICS ARR_SCH_DT ON EI_EXPO_SHPP_M(ARR_SCH_DT)
GO
CREATE STATISTICS EXRT ON EI_EXPO_SHPP_M(EXRT)
GO
CREATE STATISTICS WRHS_CD ON EI_EXPO_SHPP_M(WRHS_CD)
GO
CREATE STATISTICS SHOP_CD ON EI_EXPO_SHPP_M(SHOP_CD)
GO
CREATE STATISTICS SLP_OCRN_SN ON EI_EXPO_SHPP_M(SLP_OCRN_SN)
GO
CREATE STATISTICS SL_RCPT_NO ON EI_EXPO_SHPP_M(SL_RCPT_NO)
GO
CREATE STATISTICS SL_RCPT_SN ON EI_EXPO_SHPP_M(SL_RCPT_SN)
GO
CREATE STATISTICS SL_DT ON EI_EXPO_SHPP_M(SL_DT)
GO
CREATE STATISTICS CT_INFO_EXCL_YN ON EI_EXPO_SHPP_M(CT_INFO_EXCL_YN)
GO
CREATE STATISTICS ATRZ_USE_YN ON EI_EXPO_SHPP_M(ATRZ_USE_YN)
GO
CREATE STATISTICS SHPP_PPRS_RVW_EXCL_YN ON EI_EXPO_SHPP_M(SHPP_PPRS_RVW_EXCL_YN)
GO
CREATE STATISTICS PDITEM_SE_CD ON EI_EXPO_SHPP_M(PDITEM_SE_CD)
GO
CREATE STATISTICS RVW_STTS_CD ON EI_EXPO_SHPP_M(RVW_STTS_CD)
GO
CREATE STATISTICS SHPP_PPRS_CHG_YN ON EI_EXPO_SHPP_M(SHPP_PPRS_CHG_YN)
GO
CREATE STATISTICS SHPP_PPRS_CHG_DT ON EI_EXPO_SHPP_M(SHPP_PPRS_CHG_DT)
GO
CREATE STATISTICS SHPP_PPRS_RVW_APRV_DT ON EI_EXPO_SHPP_M(SHPP_PPRS_RVW_APRV_DT)
GO
CREATE STATISTICS INLD_TCOST ON EI_EXPO_SHPP_M(INLD_TCOST)
GO
CREATE STATISTICS INLD_COST_INVC_NO ON EI_EXPO_SHPP_M(INLD_COST_INVC_NO)
GO
CREATE STATISTICS ACTL_DEP_DT ON EI_EXPO_SHPP_M(ACTL_DEP_DT)
GO
CREATE STATISTICS ACTL_ARR_DT ON EI_EXPO_SHPP_M(ACTL_ARR_DT)
GO
CREATE STATISTICS FWDR_NM ON EI_EXPO_SHPP_M(FWDR_NM)
GO
CREATE STATISTICS RVW_OPNN_CNTN ON EI_EXPO_SHPP_M(RVW_OPNN_CNTN)
GO
CREATE STATISTICS MST_BL_NO ON EI_EXPO_SHPP_M(MST_BL_NO)
GO
CREATE STATISTICS SHPCO_CD ON EI_EXPO_SHPP_M(SHPCO_CD)
GO
CREATE STATISTICS SHPCO_NM ON EI_EXPO_SHPP_M(SHPCO_NM)
GO
CREATE STATISTICS CTNR_TRKG_YN ON EI_EXPO_SHPP_M(CTNR_TRKG_YN)
GO
CREATE STATISTICS SHIP_TRKG_STTS_CD ON EI_EXPO_SHPP_M(SHIP_TRKG_STTS_CD)
GO
CREATE STATISTICS CCO_MNG_NO ON EI_EXPO_SHPP_M(CCO_MNG_NO)
GO
CREATE STATISTICS SHPP_PPRS_VER_VAL ON EI_EXPO_SHPP_M(SHPP_PPRS_VER_VAL)
GO
CREATE STATISTICS FCT_SHPP_PPRS_RVW_STTS_CD ON EI_EXPO_SHPP_M(FCT_SHPP_PPRS_RVW_STTS_CD)
GO
CREATE STATISTICS EML_ADDR ON EI_EXPO_SHPP_M(EML_ADDR)
GO
CREATE STATISTICS DEL_YN ON EI_EXPO_SHPP_M(DEL_YN)
GO
CREATE STATISTICS ATCH_FILE_GRP_NO ON EI_EXPO_SHPP_M(ATCH_FILE_GRP_NO)
GO
CREATE STATISTICS REG_MENU_ID ON EI_EXPO_SHPP_M(REG_MENU_ID)
GO
CREATE STATISTICS REG_ID ON EI_EXPO_SHPP_M(REG_ID)
GO
CREATE STATISTICS REG_DTTM ON EI_EXPO_SHPP_M(REG_DTTM)
GO
CREATE STATISTICS MOD_MENU_ID ON EI_EXPO_SHPP_M(MOD_MENU_ID)
GO
CREATE STATISTICS MOD_ID ON EI_EXPO_SHPP_M(MOD_ID)
GO
CREATE STATISTICS MOD_DTTM ON EI_EXPO_SHPP_M(MOD_DTTM)
GO


-- 통계 재생성
EXEC SP_DBA_MAKE_STATS ERP, EI_EXPO_SHPP_M



-- 인덱스 DDL 복구
CREATE  NONCLUSTERED INDEX IX_EI_EXPO_SHPP_M_01 ON EI_EXPO_SHPP_M(COMP_CD , INVC_NO1)  ON FG_ERP_IDX
GO



------------------------------------------------------------------------------------------------SR00001695_컬럼추가 FINISH
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------






------------------------------------------------------------------------------------------------SR00001701_컬럼추가 START
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------









--
--PN_MAIN_STYL_CLR_H 
--

-- 아래는 에러 발생 쿼르

ALTER TABLE ERP.dbo.PN_MAIN_STYL_CLR_H ADD MXRT_EXPN_KOR_NM nvarchar(4000) ;
ALTER TABLE ERP.dbo.PN_MAIN_STYL_CLR_H ADD MXRT_EXPN_ENG_NM nvarchar(4000) ;
IF EXISTS (
     SELECT * FROM ::FN_LISTEXTENDEDPROPERTY ('MS_Description', 'SCHEMA', 'dbo', 'TABLE', 'PN_MAIN_STYL_CLR_H', 'COLUMN', 'MXRT_EXPN_KOR_NM')
)
    EXEC SP_UPDATEEXTENDEDPROPERTY 'MS_Description', '혼용률설명한글명' ,'SCHEMA', 'dbo', 'TABLE', 'PN_MAIN_STYL_CLR_H','COLUMN', 'MXRT_EXPN_KOR_NM'
ELSE
    EXEC SP_ADDEXTENDEDPROPERTY 'MS_Description', '혼용률설명한글명' ,'SCHEMA', 'dbo', 'TABLE','PN_MAIN_STYL_CLR_H','COLUMN', 'MXRT_EXPN_KOR_NM'

IF EXISTS (
     SELECT * FROM ::FN_LISTEXTENDEDPROPERTY ('MS_Description', 'SCHEMA', 'dbo', 'TABLE', 'PN_MAIN_STYL_CLR_H', 'COLUMN', 'MXRT_EXPN_ENG_NM')
)
    EXEC SP_UPDATEEXTENDEDPROPERTY 'MS_Description', '혼용률설명영문명' ,'SCHEMA', 'dbo', 'TABLE', 'PN_MAIN_STYL_CLR_H','COLUMN', 'MXRT_EXPN_ENG_NM'
ELSE
    EXEC SP_ADDEXTENDEDPROPERTY 'MS_Description', '혼용률설명영문명' ,'SCHEMA', 'dbo', 'TABLE','PN_MAIN_STYL_CLR_H','COLUMN', 'MXRT_EXPN_ENG_NM'

--------------- 에러 발생 이유는 무엇일까?
/*


이미 존재하는 컬럼에 대해서 ALTER TABLE ~~ ADD 실행
ALTER TABLE ERP.dbo.PN_MAIN_STYL_CLR_H ADD MXRT_EXPN_KOR_NM nvarchar(4000) ;
위 쿼리는 해당 컬럼이 없을 때만 사용 가능함
이미 존재하는 컬럼들이 모두 NUll이었기 때문에 ALTER TABEL DROP을 통해서 삭제하고 다시 실행하므로 해결함

*/




------------------------------------------------------------------------------------------------SR00001701_컬럼추가 END
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------






------------------------------------------------------------------------------------------------SR00001710 UPDATE START
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------


UPDATE EI_EXPO_CMRCL_INVC_D
SET SIGN_FILE_GRP_NO = 2017262
WHERE CONCAT(INVC_NO1, INVC_NO2) IN ('CMKRUW250197','CMKRAP250198','CMKRUW250196','CMKRAP250190');



------------------------------------------------------------------------------------------------SR00001710 UPDATE END
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------