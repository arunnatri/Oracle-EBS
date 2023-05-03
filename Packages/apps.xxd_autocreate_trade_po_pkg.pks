--
-- XXD_AUTOCREATE_TRADE_PO_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AUTOCREATE_TRADE_PO_PKG"
AS
    /*******************************************************************************
     * Program Name : XXD_AUTOCREATE_TRADE_PO_PKG
     * Language     : PL/SQL
     * Description  : This package will autocreate PO from Trade requisitions Only
     * History      :
     *   WHO            WHAT              Desc                             WHEN
     * -------------- ---------------------------------------------- ---------------
     * Infosys          1.0          Initial Version                    12-Mar-2018
     * GJensen          1.1           Modified for US Direct Ship CCR0007687   7-Jan-2018
     * --------------------------------------------------------------------------- */

    --Begin CCR0007687
    --Declared to allow use in CURSOR to get PO header data
    FUNCTION GET_PO_TYPE (pn_req_header_id IN NUMBER, pv_drop_ship_flag IN VARCHAR2, pv_hrorg IN VARCHAR2
                          , pv_item_type IN VARCHAR2)
        RETURN VARCHAR2;

    --End CCR0007687

    --Copy of entry function with DUMMY parameter to accomidate the hidden parameter in the Concurrent request from
    PROCEDURE XXD_START_AUTOCREATE_PO (
        P_ERRBUF         OUT NOCOPY VARCHAR2,
        P_RETCODE        OUT NOCOPY NUMBER,
        P_PO_TYPE     IN            VARCHAR2,
        P_DUMMY       IN            VARCHAR2 := NULL,
        P_BUYER_ID    IN            VARCHAR2,
        P_OU          IN            NUMBER,
        P_PO_STATUS   IN            VARCHAR2,
        P_REQ_ID      IN            NUMBER DEFAULT NULL);
END XXD_AUTOCREATE_TRADE_PO_PKG;
/
