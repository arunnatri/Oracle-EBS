--
-- XXD_IEX_CREDIT_SCORE_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_IEX_CREDIT_SCORE_RPT_PKG"
AS
    --------------------------------------------------------------------------------
    -- Created By              : BT Technology Team
    -- Creation Date           : 31-Mar-2015
    -- File Name               : XXD_IEX_CREDIT_SCORE_RPT_PKG.pks
    -- INCIDENT                : Deckers Credit Outbound Program US
    --
    -- Description             :
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                 Remarks
    -- =============================================================================
    -- 31-MAR-2015        1.0         BT Technology Team  Initial development.
    -------------------------------------------------------------------------------
    P_OU                         VARCHAR2 (200);
    P_PARTY_NAME                 VARCHAR2 (200);
    P_PARTY_NUMBER               VARCHAR2 (200);
    P_AS_OF_DATE                 VARCHAR2 (200);
    P_PARTY_CREATION_DATE_FROM   VARCHAR2 (200);
    P_PARTY_CREATION_DATE_TO     VARCHAR2 (200);

    FUNCTION AFTER_REPORT
        RETURN BOOLEAN;
END XXD_IEX_CREDIT_SCORE_RPT_PKG;
/
