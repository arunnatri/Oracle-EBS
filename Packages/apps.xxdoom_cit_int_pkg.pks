--
-- XXDOOM_CIT_INT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOOM_CIT_INT_PKG"
/*
================================================================
 Created By              : Venkatesh Ragamgari
 Creation Date           : 31-Jan-2011
 File Name               : XXDOOM_CIT_INT_PKG.pkb
 Work Order Num          : Sanuk CIT Interface
 Incident Num            :
 Description             :
 Latest Version          : 1.1
 Revision History        : a. Modified to exclude the Return
                              Lines
                       b. Modified to send whatever value
                              from Attribute13 of sales order
================================================================
 Date               Version#    Name                    Remarks
================================================================
 18-NOV-2011        1.0         Venkatesh Ragamgari
 13-Dec-2013        1.1         Madhav Dhurjaty         Modified MAIN for CIT FTP Change ENHC0011747
 04-DEC-2014        1.2         BT Technology Team      Modified function  is_fact_cust_f and is_credit_check_req_f according to MD50
 16-JAN-2014        2.1         BT Technology Team      Added two more parameters in 'main' and 'outbound' procedure i.e pd_order_from_date and pd_order_to_date
================================================================

*/
AS
    FUNCTION cust_phone_f (pn_cust_acct_id       NUMBER,
                           pn_cust_site_use_id   NUMBER)
        RETURN NUMBER;

    FUNCTION is_fact_cust_f (pv_order_number   VARCHAR2,
                             pn_cust_acct      NUMBER,
                             pn_bill_to        NUMBER)
        RETURN VARCHAR2;

    FUNCTION cit_terms_date_f (pn_header_id NUMBER, pd_start_date VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION is_credit_check_req_f (pn_cust_acct NUMBER, pn_bill_to NUMBER)
        RETURN VARCHAR2;

    FUNCTION phone_format_f (pn_raw_phone VARCHAR2)
        RETURN NUMBER;

    PROCEDURE main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_new_orders IN VARCHAR2, pv_brand IN VARCHAR2, pd_from_date IN VARCHAR2, pd_to_date IN VARCHAR2, pv_days IN NUMBER, pv_transmit_file IN VARCHAR2, --   Started added by BT Technology Team on 16-JAN-2015 version(2.1)
                                                                                                                                                                                                                         pd_order_from_date IN VARCHAR2
                    , pd_order_to_date IN VARCHAR2, --   Ended added by BT Technology Team on 16-JAN-2015 version(2.1)
                                                    --  Started added by BT Technology Team on 16-FEB-2015 version(2.1)
                                                    p_order_number_from IN NUMBER, p_order_number_to IN NUMBER--   Ended added by BT Technology Team on 16-FEB-2015 version(2.1)
                                                                                                              );

    PROCEDURE order_outbound (errbuf                   OUT VARCHAR2,
                              retcode                  OUT VARCHAR2,
                              pv_new_orders         IN     VARCHAR2,
                              pv_brand              IN     VARCHAR2,
                              pd_from_date          IN     VARCHAR2,
                              pd_to_date            IN     VARCHAR2,
                              pv_days               IN     NUMBER,
                              --   Started added by BT Technology Team on 16-JAN-2015 version(2.1)
                              pd_order_from_date    IN     VARCHAR2,
                              pd_order_to_date      IN     VARCHAR2,
                              --   Ended added by BT Technology Team on 16-JAN-2015 version(2.1)
                              --  Started added by BT Technology Team on 16-FEB-2015 version(2.1)
                              p_order_number_from   IN     NUMBER,
                              p_order_number_to     IN     NUMBER--   Ended added by BT Technology Team on 16-FEB-2015 version(2.1)
                                                                 );
END xxdoom_cit_int_pkg;
/
