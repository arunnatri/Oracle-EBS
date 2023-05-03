--
-- XXDOPO_PRICE_UPDATE_PKG  (Package) 
--
--  Dependencies: 
--   PO_API_ERRORS_REC_TYPE (Type)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOPO_PRICE_UPDATE_PKG"
IS
    /*
    **+-------------------------------------------------------------------------------------------
    **| deckers Outdoor Corporation. PO Price Update Implementation
    **|  Program NAME: PO - Inbound
    **+-------------------------------------------------------------------------------------------
    **| Implemented by: Deckers Outdoor corporation
    **+-------------------------------------------------------------------------------------------
    **| package_name : XXDOPO_PRICE_UPDATE_PKG
    **| file name    : XXDOPO_PRICE_UPDATE_PKG.pkh
    **| type         : package body
    **| creation date: Nov 30 2011
    **| author       :
    **| comments     :The purpose of this api is to process the  new price for the PO Lines based on Style and Color ,
                      validate the contents and completeness of the records and process them. When processed successfully,
                      Purchase Orders are  Updated in Oracle Purchasing  to reflect the new price.
    **+---------------------------------------------------------------------------------------------------------------------------------
    **|Version          Who                       Date                        Comments
    **| 1.0             Man Mohan Kummari         30 Nov 2011                  Initial
    **| 1.1             BT Technology Team        12-Dec-2014       Retrofit Changes done for R12.2.3 Upgrade
    **+----------------------------------------------------------------------------------------------------------------------------------
    /* Procedure to get the lines for which the update API has to be executed*/
    PROCEDURE PRICE_UPDATE_API (PN_RESULT OUT NUMBER, PV_PO_NUMBER VARCHAR2, PV_RELEASE_NUMBER NUMBER, PV_REVISION_NUMBER NUMBER, PV_LINE_NUMBER NUMBER, PV_SHIPMENT_NUMBER VARCHAR2, PV_NEW_QUANTITY NUMBER, PV_NEW_PRICE NUMBER, PV_NEW_PROMISED_DATE DATE, PV_NEW_NEED_BY_DATE DATE, PV_LAUNCH_APPROVALS_FLAG VARCHAR2, PV_UPDATE_SOURCE VARCHAR2, PV_VERSION VARCHAR2, PV_OVERRIDE_DATE DATE, PV_API_ERRORS OUT apps.PO_API_ERRORS_REC_TYPE, PV_BUYER_NAME VARCHAR2, PV_SECONDARY_QUANTITY NUMBER, PV_PREFERRED_GRADE VARCHAR2
                                , PV_ORG_ID NUMBER);

    /* Procedure to update the table with the errors from the form*/
    PROCEDURE PRICE_UPDATE_ERRORS (PV_STYLE VARCHAR2, PV_COLOR VARCHAR2, PV_SIZE_ITEM VARCHAR2, PV_NEW_PRICE VARCHAR2, PV_PO_NUMBER VARCHAR2, PV_PO_LINE VARCHAR2, PV_BUY_SEASON VARCHAR2, PV_BUY_MONTH VARCHAR2, PV_PO_HEADER_ID VARCHAR2, PV_PO_LINE_ID VARCHAR2, PV_PO_ITEM_ID VARCHAR2, PV_PO_LINE_LOCATION_ID VARCHAR2
                                   , PV_ERROR_DETAILS VARCHAR2);

    /* Procedure to collect the reords to pass onto the procedure : PRICE_UPDATE_API for price update*/
    PROCEDURE PRICE_UPDATE (ERRBUFF OUT VARCHAR2, RETCODE OUT NUMBER, PV_STYLE VARCHAR2, PV_COLOR VARCHAR2, PV_BUY_SEASON VARCHAR2, PV_BUY_MONTH VARCHAR2, PV_PO_NUMBER VARCHAR2, PV_NEW_PRICE VARCHAR2, PV_SIZE VARCHAR2
                            , PV_CXFDATE VARCHAR2);
END;
/
