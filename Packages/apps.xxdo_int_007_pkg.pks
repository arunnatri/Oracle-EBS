--
-- XXDO_INT_007_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INT_007_PKG"
IS
    /**********************************************************************************************************

     File Name    : xxdo_int_007_pkg

     Created On   : 01-MARCH-2012

     Created By   : Abdul and Sivakumar Boothathan

     Purpose      : Package used to find the shipments made for a order with an order source as "Retail"
                    The columns which were picked up are to_location_id, from_location_id and other columns
                    We make use of a custom lookup : XXDO_RETAIL_STORE_CUST_MAPPING which will be used to
                    map the store number in RMS with the customer number in EBS
                    If the net quantity is greater than zero which means we need to call on INT-009 which is
                    a message for cancel or backorder, for every backorder or for every cancellation we need
                    to send INT-009
    ***********************************************************************************************************
    Modification History:
    Version   SCN#   By              Date             Comments
    1.0              Abdul and Siva    15-Feb-2012       NA
   2.0              BT Technology team 22-July-2014      NA
   3.0                 Middleware            03-May-2018        Added new function to get seq no
    *********************************************************************
    Parameters: 1.Reprocess
                2.Reprocess dates
    *********************************************************************/

    PROCEDURE xxdo_int_007_main_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_deliver_number IN VARCHAR2
                                     , p_reprocess_flag IN VARCHAR2, p_reprocess_from IN VARCHAR2, p_reprocess_to IN VARCHAR2);

    PROCEDURE xxdo_int_007_main_prc_union (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_deliver_number IN VARCHAR2
                                           , p_reprocess_flag IN VARCHAR2, p_reprocess_from IN VARCHAR2, p_reprocess_to IN VARCHAR2);

    PROCEDURE xxdo_int_007_main_prc_new (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_deliver_number IN VARCHAR2
                                         , p_reprocess_flag IN VARCHAR2, p_reprocess_from IN VARCHAR2, p_reprocess_to IN VARCHAR2);

    PROCEDURE xxdo_int_007_processing_msgs (p_sysdate          IN DATE,
                                            p_deliver_number   IN VARCHAR2);

    FUNCTION xxdo_Get_distro_no (v_line_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION xxdo_Get_xml_id (v_line_id NUMBER)
        RETURN NUMBER;

    FUNCTION xxdo_Get_seq_no (v_line_id NUMBER)
        RETURN NUMBER;
END xxdo_int_007_pkg;
/
