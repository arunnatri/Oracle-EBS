--
-- XXDOINV_PITEMCOST_SYNC_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDOINV_PITEMCOST_SYNC_PKG
IS
    /***************************************************************************
    Package Name : APPS.XXDOINV_PITEMCOST_SYNC_PKG
    Description: This package is used for to get all items which costmissmatch between EBS and RMS and publish cost in RMS.

    a.  PUBLISH_ITEMCOSTCHANGE_P

        This procedure is used to get all items which costmismatch between EBS and RMS and insert into XXDOINV010_INT

         with RMS using WebService call including the   Vertex tax logic
    b. RMS_BATCH_ITEMCOSTCHANGE_P

        This procedure is used to publish item cost from Staging table to RMS by using WEB services.


                Creation on 10/15/2013
                Created by : Nagapratap

      -------------------------------------------------------
    **************************************************************************/
    FUNCTION get_no_of_items_inpack_f (pn_item_id NUMBER)
        RETURN NUMBER;

    PROCEDURE RMS_PUBLISH_ITEMCOSTCHANGE_P (pv_errorbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_rundate IN VARCHAR2
                                            , pv_region IN VARCHAR2--pv_item_id          NUMBER DEFAULT NULL
                                                                   );

    PROCEDURE rms_batch_itemcostchange_p (
        errbuf                   OUT VARCHAR2,
        retcode                  OUT VARCHAR2,
        p_slno_from           IN     NUMBER,
        p_slno_to             IN     NUMBER,
        p_parent_request_id          NUMBER);
END;
/
