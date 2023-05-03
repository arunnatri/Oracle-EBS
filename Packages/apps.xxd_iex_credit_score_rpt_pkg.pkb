--
-- XXD_IEX_CREDIT_SCORE_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:44 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_IEX_CREDIT_SCORE_RPT_PKG"
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
    FUNCTION AFTER_REPORT
        RETURN BOOLEAN
    AS
        ln_request_id   NUMBER;
    BEGIN
        ln_request_id   :=
            FND_REQUEST.SUBMIT_REQUEST (
                APPLICATION   => 'XDO',                         -- APPLICATION
                PROGRAM       => 'XDOBURSTREP',                     -- PROGRAM
                DESCRIPTION   => 'Bursting',                    -- DESCRIPTION
                ARGUMENT1     => 'N',
                ARGUMENT2     => FND_GLOBAL.CONC_REQUEST_ID,
                -- ARGUMENT1
                ARGUMENT3     => 'Y'                              -- ARGUMENT2
                                    );
        COMMIT;
        RETURN (TRUE);
    END AFTER_REPORT;
END XXD_IEX_CREDIT_SCORE_RPT_PKG;
/
