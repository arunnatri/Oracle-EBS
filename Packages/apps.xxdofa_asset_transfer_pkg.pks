--
-- XXDOFA_ASSET_TRANSFER_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDOFA_ASSET_TRANSFER_PKG
AS
    /******************************************************************************
       NAME:       XXDOFA_ASSET_TRANSFER_PKG
       PURPOSE:

       REVISIONS:
       Ver        Date        Author                    Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        15/09/2014    BT TechnologyTeam     Created
    ******************************************************************************/
    p_sob_id         NUMBER;
    P_BOOK_TYPE      VARCHAR2 (50);
    P_START_PERIOD   VARCHAR2 (15);
    P_END_PERIOD     VARCHAR2 (15);
    g_table          VARCHAR2 (50);
    g_where          VARCHAR2 (1000);
    g_currency       VARCHAR2 (3);

    FUNCTION GET_ADJ_TABLE (p_sob_id IN NUMBER)
        RETURN BOOLEAN;
END XXDOFA_ASSET_TRANSFER_PKG;
/
