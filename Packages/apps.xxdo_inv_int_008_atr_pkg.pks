--
-- XXDO_INV_INT_008_ATR_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INV_INT_008_ATR_PKG"
IS
    /**********************************************************************************************************
     File Name    : xxdo_inv_int_008_atr_pkg.sql
     Created On   : BT Technology Team
     Created By   : Viswanath and Sivakumar Boothathan
     Purpose      : Package used to calculate the ATR data and insert into the custom table : xxdo_inv_int_008
                    1. The logic to calculate the ATR is to find out the least of Free ATP + KCO and ATR
                    2. Once we get the ATR value, the values required to insert the table as per the RMS mapping
                       is inserted into the table.
                    3. The status flag "Y" is inserted into the custom table which confirms that the data has been
                       processed by EBS an sent to RMS.
                    4.
    ***********************************************************************************************************
    Modification History:
    Version   SCN#   By                     Date             Comments
    1.0              BT Technology Team     12-AUG-2014      NA
    2.1              Infosys                10-oct-2016      NA
    *********************************************************************
    Parameters: 1. Load Type
                2. Free ATP
                3. Reprocess
                4. Virtual warehouse ID
    *********************************************************************/
    ---------------------------------------------------------------------
    -- Procedure xxdo_inv_int_008_prc which is the main procedure which
    -- is used to select the ATR and insert into the custom table
    --------------------------------------------------------------------
    PROCEDURE xxdo_inv_int_008_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_vm_id IN VARCHAR2, p_load_type IN VARCHAR2, p_reprocess IN VARCHAR2, p_reprocess_from IN VARCHAR2, p_reprocess_to IN VARCHAR2, p_style IN VARCHAR2, p_color IN VARCHAR2
                                    , p_number_of_days IN NUMBER);

    PROCEDURE xxdo_inv_int_pub_atr_p (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_cur_limit IN NUMBER
                                      , p_request_leg IN NUMBER);


    PROCEDURE xxdo_inv_int_pub_bth_atr_p (errbuf             OUT VARCHAR2,
                                          retcode            OUT VARCHAR2,
                                          p_cur_limit     IN     NUMBER,
                                          p_request_leg   IN     NUMBER,
                                          p_dc_dest_id    IN     NUMBER --Added by infosys for version 2.1
                                                                       );

    -----------------------
    -- End of the procedure
    -----------------------

    FUNCTION GET_ATR_OPEN_ALLOCATION_F (pv_item_id NUMBER, pv_org_id NUMBER)
        RETURN NUMBER;
END;
/
