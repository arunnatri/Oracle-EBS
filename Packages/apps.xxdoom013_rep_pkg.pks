--
-- XXDOOM013_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOOM013_REP_PKG"
AS
    /******************************************************************************
       NAME: XXDOOM013_REP_PKG
       REP NAME:UK Item Tax Exemption Interface - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       11/29/2012     Shibu        1. Created this package for XXDOOM013_REP_PKG Process
    ******************************************************************************/

    PROCEDURE TAX_EXEMPT_ITEMS (PV_ERRBUF                OUT VARCHAR2,
                                PV_RETCODE               OUT VARCHAR2,
                                PN_CONTENT_OWNER_ID          NUMBER,
                                PV_TAX_RATE_CODE             VARCHAR2,
                                PV_EXEMPT_REASON             VARCHAR2,
                                PV_EXEMPT_START_DT           VARCHAR2,
                                PN_MST_INV_ORG               NUMBER,
                                PV_EXEMPT_TAX_CLASS_ID       NUMBER);
END XXDOOM013_REP_PKG;
/
