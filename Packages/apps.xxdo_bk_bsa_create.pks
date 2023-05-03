--
-- XXDO_BK_BSA_CREATE  (Package) 
--
--  Dependencies: 
--   OE_BLANKET_HEADERS_ALL (Synonym)
--   OE_BLANKET_PUB (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_BK_BSA_CREATE"
AS
    /**********************************************************************************************************
        file name    : XXDO_BK_BSA_CREATE.pks
        created on   : 24-FEB-2015
        created by   : INFOSYS
        purpose      : package specification used for the following
                               1. To create the sales agreement from a Belk BK File of EDI850
                               2. Return the sales agreement number and sales agreement line number
       ****************************************************************************
       Modification history:
      *****************************************************************************

          Version        Date        Author           Description
          ---------  ----------  ---------------  ------------------------------------
          1.0         24-FEB-2015     INFOSYS       1.Created
          1.1         01-JUN-2015     INFOSYS      2. Included parameters needed for Customer PO check in the BSA validation.
     *********************************************************************
     *********************************************************************/

    PROCEDURE bsa_create (
        p_cust_name         IN     VARCHAR2,
        p_brand             IN     VARCHAR2,
        p_org_id            IN     NUMBER,
        p_cust_po_number    IN     VARCHAR2,
        p_end_date_active   IN     VARCHAR2 DEFAULT NULL,
        p_bsa_name          IN     VARCHAR2 DEFAULT NULL,
        p_requested_date    IN     VARCHAR2 DEFAULT TO_CHAR (TRUNC (SYSDATE),
                                                             'DD-MON-RRRR'),
        p_ordered_date      IN     VARCHAR2 DEFAULT TO_CHAR (TRUNC (SYSDATE),
                                                             'DD-MON-RRRR'),
        p_line_tbl          IN     OE_BLANKET_PUB.line_tbl_Type,
        p_ret_code             OUT NUMBER,
        p_err_msg              OUT VARCHAR2,
        p_bsa_number           OUT oe_blanket_headers_all.order_number%TYPE);

    PROCEDURE get_def_rul_seq (p_attr_name_in   IN     VARCHAR2,
                               p_attr_val_out      OUT VARCHAR2);

    PROCEDURE get_attr_val (p_src_type IN VARCHAR2, p_SRC_API_PKG IN VARCHAR2 DEFAULT NULL, p_SRC_API_FN IN VARCHAR2 DEFAULT NULL, p_src_profile_option IN VARCHAR2 DEFAULT NULL, p_src_constant_value IN VARCHAR2 DEFAULT NULL, p_src_system_variable_expr IN VARCHAR2 DEFAULT NULL
                            , p_src_database_object_name IN VARCHAR2 DEFAULT NULL, p_attribute_code IN VARCHAR2, p_attr_val OUT VARCHAR2);

    FUNCTION get_site_use_id (p_site_use_code IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_sales_rep_id (p_inv_item_id IN NUMBER, p_org_id IN NUMBER, p_cust_acct_id IN NUMBER
                               , p_ship_to_org_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_blanket_hdr (p_cust_acct_id   IN NUMBER,
                              p_org_id         IN NUMBER,
                              p_cust_po_num    IN VARCHAR2)   -- Added for 1.1
        RETURN NUMBER;

    FUNCTION get_blanket_line (p_cust_acct_id IN NUMBER, p_org_id IN NUMBER, p_inv_item_id IN NUMBER
                               , p_cust_po_num IN VARCHAR2)   -- Added for 1.1
        RETURN NUMBER;

    PROCEDURE log_errors_bk (p_err_num IN NUMBER, p_pkg_name IN VARCHAR2, p_proc_name IN VARCHAR2
                             , p_err_msg IN VARCHAR2);
/* -- Commmented since not being used.
PROCEDURE log_errors_rl (p_err_num     IN NUMBER,
                         p_pkg_name    IN VARCHAR2,
                         p_proc_name   IN VARCHAR2,
                         p_err_msg     IN VARCHAR2); */
END XXDO_BK_BSA_CREATE;
/


--
-- XXDO_BK_BSA_CREATE  (Synonym) 
--
--  Dependencies: 
--   XXDO_BK_BSA_CREATE (Package)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXDO_BK_BSA_CREATE FOR APPS.XXDO_BK_BSA_CREATE
/


GRANT EXECUTE ON APPS.XXDO_BK_BSA_CREATE TO SOA_INT
/
