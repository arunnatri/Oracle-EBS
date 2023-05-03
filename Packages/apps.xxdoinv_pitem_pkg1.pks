--
-- XXDOINV_PITEM_PKG1  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINV_PITEM_PKG1"
IS
    /*******************************************************************************
    * Program Name : XXDOINV_PITEM_PKG1
    * Language     : PL/SQL
    * Description: This package is used for Integration of following

    a.  Item Description Messages of
        1. Style  => Creation, Modification
        2. Sku    => Creation, Modification
        3. Upc    => Creation, Modification

         with RMS using WebService call including the   Vertex tax logic
    b. Item Location Messages of
        1. Style
                a. Store     => Creation, Modification
                b. Warehouse => Creation, Modification
        2. Sku
                a. Store     => Creation, Modification
                b. Warehouse => Creation, Modification

                Creation on 2/24/2012
                Created by : Sunera Technologies
     c. Modified the Item Loc with the following
        1. Region if it is not available , also to verify at the Pricelists
        2. Update only when Description  / Status/ Region is changed

                Updated on 4-MAR-2012
                Updaet BY: Naga Pratap  Vikranth
     1)  Integration of Hongkong Region, Sanuk Brand Integratation and transmission of Store w.r.t. to Brands
     2) Redesigned Item Loc Integration Program to Improve the Performance of the Interfaces.
     3) Addition of UK3 Region.
      --------------------------------------------------------
      Changes made Vishal on 08-NOV-2012 in all procedures
      to pick even non active status items
      -------------------------------------------------------

       -------------------------------------------------------
      Changes made Reddeiah on 26 -May-2014 in all procedures
      to exclude sample items  --DFCT0010916
      -------------------------------------------------------
       History      :
    *
    * WHO                    WHAT              Desc                             WHEN
    * -------------- ---------------------------------------------- ---------------------
    * BT Technology Team     1.0                                             17-JUL-2014
    * Kranthi Bollam         2.1       For CCR0004924 -Issue with Label      22-JUN-2016
                                       Printing for Kids Shoes for APAC
    *********************************************************************
    Procedure for sending Item Location for Style Creation or Updation
    **************************************************************************/
    /*Procedure PUBLISH_PING_P( PV_INXML SYS.XMLTYPE,PV_OUTXML OUT SYS.XMLTYPE );
    Function PUBLISH_ITEM_F( PV_INXML SYS.XMLTYPE ) RETURN  SYS.XMLTYPE;
    Function PUBLISH_ITEMLOC_F(PV_INXML SYS.XMLTYPE) RETURN SYS.XMLTYPE; */
    FUNCTION get_updatecat_f (pv_rundate   VARCHAR2,
                              pn_item_id   NUMBER,
                              pn_org_id    NUMBER)
        RETURN VARCHAR2;

    PROCEDURE publish_itemloc_p (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_rundate VARCHAR2
                                 , pv_reprocess VARCHAR2, pv_fromdate VARCHAR2, pv_todate VARCHAR2);

    PROCEDURE publish_itemlocsku_p (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_rundate VARCHAR2
                                    , pv_reprocess VARCHAR2, pv_fromdate VARCHAR2, pv_todate VARCHAR2);

    PROCEDURE publish_item_p (pv_errorbuf    OUT VARCHAR2,
                              pv_retcode     OUT VARCHAR2,
                              pv_rundate         VARCHAR2,
                              pv_reprocess       VARCHAR2,
                              pv_fromdate        VARCHAR2,
                              pv_todate          VARCHAR2);

    PROCEDURE publish_itemsku_p (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_rundate VARCHAR2
                                 , pv_reprocess VARCHAR2, pv_fromdate VARCHAR2, pv_todate VARCHAR2);

    PROCEDURE publish_itemupc_p (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_rundate VARCHAR2
                                 , pv_reprocess VARCHAR2, pv_fromdate VARCHAR2, pv_todate VARCHAR2);

    PROCEDURE publish_itemcostchange_p (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_rundate VARCHAR2
                                        , pv_reprocess VARCHAR2, pv_fromdate VARCHAR2, pv_todate VARCHAR2);

    PROCEDURE publish_itemuda_update (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_rundate VARCHAR2
                                      , pv_reprocess VARCHAR2, pv_fromdate VARCHAR2, pv_todate VARCHAR2);

    FUNCTION xxdo_get_price_list (p_region VARCHAR2)
        RETURN NUMBER;

    FUNCTION xxdo_get_japan_price (p_flag    NUMBER,
                                   p_style   VARCHAR2,
                                   p_item    VARCHAR2)
        RETURN VARCHAR2;

    -- Added by Jayaprakash as part of ENHC0011935
    -- This procedure is used to call webservice program in batches
    PROCEDURE rms_batch_item_p (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_slno_from IN NUMBER
                                , p_slno_to IN NUMBER, p_parent_request_id IN NUMBER, program_name IN VARCHAR2);

    -- Added by Jayaprakash as part of ENHC0011935
    -- This procedure is used to send an email after completion of program
    PROCEDURE send_email_proc (p_program_name VARCHAR2);

    -- Added by Jayaprakash as part of ENHC0011935
    -- This procedure is used to send an email after completion of TAX UDA program
    PROCEDURE send_email_tax_uda_proc;

    --Start of Change 2.1
    --Added for change 2.1
    PROCEDURE publish_subdiv_itemuda_upd (pv_errorbuf    OUT VARCHAR2,
                                          pv_retcode     OUT VARCHAR2,
                                          pv_rundate         VARCHAR2,
                                          pv_reprocess       VARCHAR2,
                                          pv_fromdate        VARCHAR2,
                                          pv_todate          VARCHAR2,
                                          pv_style           VARCHAR2,
                                          pn_item_id         NUMBER);

    --Added for change 2.1
    FUNCTION get_item_sub_division (p_inventory_item_id   IN NUMBER,
                                    p_organization_id     IN NUMBER)
        RETURN VARCHAR2;

    --Added for change 2.1
    FUNCTION get_item_sub_div_cre_dt (p_inventory_item_id   IN NUMBER,
                                      p_organization_id     IN NUMBER)
        RETURN VARCHAR2;

    --Added for change 2.1
    FUNCTION get_item_sub_div_last_upd_by (p_inventory_item_id   IN NUMBER,
                                           p_organization_id     IN NUMBER)
        RETURN VARCHAR2;

    --Added for change 2.1
    PROCEDURE send_email_subdiv_uda_proc;
--End of Change 2.1

END;
/
