-- 아래는 에러 발생 쿼리

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



