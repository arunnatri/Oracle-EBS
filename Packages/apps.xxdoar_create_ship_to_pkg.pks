--
-- XXDOAR_CREATE_SHIP_TO_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAR_CREATE_SHIP_TO_PKG"
AS
    /*******************************************************************************
      * Program Name : XXDOAR_CREATE_SHIP_TO_PKG
      * Language     : PL/SQL
      * Description  : This package will Loading Shipto Data from Staging - Deckers
      *
      * History      :
      *
      * WHO               WHAT              Desc                             WHEN
      * -------------- ---------------------------------------------- ---------------
      * BT Technology Team                                               NOV/18/2014
      * --------------------------------------------------------------------------- */
    PROCEDURE xxdo_create_ship_to (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pv_file_loc IN VARCHAR2
                                   , pv_file_name IN VARCHAR2, pn_account IN NUMBER, pn_org IN NUMBER);

    PROCEDURE xxdo_update_stg;
END xxdoar_create_ship_to_pkg;
/
