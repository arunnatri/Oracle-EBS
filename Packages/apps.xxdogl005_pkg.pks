--
-- XXDOGL005_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDOGL005_PKG
AS
    PROCEDURE MAIN (PV_ERRBUF             OUT VARCHAR2,
                    PV_RETCODE            OUT VARCHAR2,
                    PV_RUNDATE         IN     VARCHAR2,
                    PV_REPROCESSFLAG   IN     VARCHAR2,
                    PV_REPROCESSDATE   IN     VARCHAR2);
END XXDOGL005_PKG;
/
