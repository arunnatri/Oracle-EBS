--
-- XXD_AUTOCREATE_PO_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AUTOCREATE_PO_PKG"
AS
    /*******************************************************************************
     * Program Name : xxd_AUTOCREATE_PO_PKG
     * Language     : PL/SQL
     * Description  : This package will autocreate PO from requisitions
     *
     * History      :
     *
     * WHO            WHAT              Desc                             WHEN
     * -------------- ---------------------------------------------- ---------------
     * BT Technology          1.0 - Initial Version                         JAN/15/2015
        * BT Technology                                                             1.4 - Modified for Defect#3379         Oct/22/2015
     * --------------------------------------------------------------------------- */

    PROCEDURE XXD_START_AUTOCREATE_PO (P_ERRBUF OUT NOCOPY VARCHAR2, P_RETCODE OUT NOCOPY NUMBER, P_PO_TYPE IN VARCHAR2, P_BUYER_ID IN VARCHAR2, P_OU IN NUMBER, P_PO_STATUS IN VARCHAR2
                                       , P_REQ_ID IN NUMBER DEFAULT NULL);

    --Copy of entry function with DUMMY parameter to accomidate the hidden parameter in the Concurrent request form
    PROCEDURE XXD_START_AUTOCREATE_PO (
        P_ERRBUF         OUT NOCOPY VARCHAR2,
        P_RETCODE        OUT NOCOPY NUMBER,
        P_PO_TYPE     IN            VARCHAR2,
        P_DUMMY       IN            VARCHAR2 := NULL,
        P_BUYER_ID    IN            VARCHAR2,
        P_OU          IN            NUMBER,
        P_PO_STATUS   IN            VARCHAR2,
        P_REQ_ID      IN            NUMBER DEFAULT NULL);

    PROCEDURE XXD_REQUISITION_IMPORT (P_ERRBUF OUT VARCHAR2, P_RETCODE OUT NUMBER, P_OU IN NUMBER
                                      , p_num_of_days IN NUMBER --ADDED AS PER DEFECT#3379
                                                               );

    --Unit test functions
    FUNCTION TEST_GET_REQ_VENDOR (P_ORG_ID IN NUMBER, P_DESTINATION_ORGANIZATION_ID IN NUMBER, P_ITEM_ID IN NUMBER
                                  , P_CREATION_DATE IN DATE, P_INTERNAL_ORG IN VARCHAR2, P_ORDER_TYPE IN VARCHAR2)
        RETURN NUMBER;


    FUNCTION TEST_GET_REQ_VENDOR_SITE (P_ORG_ID IN NUMBER, P_DESTINATION_ORGANIZATION_ID IN NUMBER, P_ITEM_ID IN NUMBER
                                       , P_CREATION_DATE IN DATE, P_INTERNAL_ORG IN VARCHAR2, P_ORDER_TYPE IN VARCHAR2)
        RETURN NUMBER;
END;
/
