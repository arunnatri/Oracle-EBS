--
-- XXD_BOM_UNINV_RPT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_BOM_UNINV_RPT_PKG"
    AUTHID CURRENT_USER
AS
    /**************************************************************************************************
    * Package         : XXD_BOM_UNINV_RPT_PKG
    * Description     : This package is used for Inventory Aging Details Report - Deckers
    * Notes           : Oracle apps custom reports, output file excel
    * Modification    :
    *-------------------------------------------------------------------------------------------------
    * Date         Version#   Name                  Description
    *-------------------------------------------------------------------------------------------------
    * 20-JUN-2017  1.0        Greg Jensen           Initial Version(copied from stg pkg) - CCR0006335
    * 17-Jan-2022  1.1        Aravind Kannuri       Changes for CCR0009783
    *
    **************************************************************************************************/
    --
    --   Pre-reqs        : None.
    --   Parameters      :
    --   IN              :
    --     p_title                  VARCHAR2  Required
    --     p_accrued_receipts       VARCHAR2  Required
    --     p_inc_online_accruals    VARCHAR2  Required
    --     p_inc_closed_pos         VARCHAR2  Required
    --     p_struct_num             NUMBER    Required
    --     p_category_from          VARCHAR2  Required
    --     p_category_to            VARCHAR2  Required
    --     p_min_extended_value     NUMBER    Required
    --     p_period_name            VARCHAR2  Required
    --     p_vendor_from            VARCHAR2  Required
    --     p_vendor_to              VARCHAR2  Required
    --     p_orderby                VARCHAR2  Required
    --     p_age_greater_then       VARCHAR2  Required
    --     p_cut_off_date           VARCHAR2  Required
    --     p_qty_precision          NUMBER    Required
    --
    --   OUT             :
    --     errbuf             VARCHAR2
    --     retcode            NUMBER
    --
    --   Version : Current version       1.0
    --
    -- End of comments
    -----------------------------------------------------------------------------

    PROCEDURE Start_Process (
        errbuf                     OUT NOCOPY VARCHAR2,
        retcode                    OUT NOCOPY NUMBER,
        p_title                 IN            VARCHAR2,
        p_accrued_receipts      IN            VARCHAR2,
        p_inc_online_accruals   IN            VARCHAR2,
        p_inc_closed_pos        IN            VARCHAR2,
        p_struct_num            IN            NUMBER,
        p_category_from         IN            VARCHAR2,
        p_category_to           IN            VARCHAR2,
        p_min_accrual_amount    IN            NUMBER,
        p_period_name           IN            VARCHAR2,
        p_vendor_from           IN            VARCHAR2,
        p_vendor_to             IN            VARCHAR2,
        p_orderby               IN            VARCHAR2,
        p_age_greater_then      IN            VARCHAR2,        --Added for 1.1
        p_cut_off_date          IN            VARCHAR2,        --Added for 1.1
        p_qty_precision         IN            NUMBER := 2);

    -----------------------------------------------------------------------------
    -- Start of comments
    --   API name        : Generate_XML
    --   Type            : Private
    --   Function        : The procedure generates and returns the XML data for
    --                     the reference cursor passed by the calling API.
    --
    --   Pre-reqs        : None.
    --   Parameters      :
    --   IN              :
    --     p_api_version      NUMBER        Required
    --     p_init_msg_list    VARCHAR2      Required
    --     p_validation_level NUMBER        Required
    --     p_ref_cur          SYS_REFCURSOR Required
    --     p_row_tag          VARCHAR2      Required
    --     p_row_set_tag      VARCHAR2      Required
    --
    --   OUT             :
    --     x_return_status    VARCHAR2
    --     x_msg_count        NUMBER
    --     x_msg_data         VARCHAR2
    --     x_xml_data         CLOB
    --
    --   Version : Current version       1.0
    --
    -- End of comments
    -----------------------------------------------------------------------------
    PROCEDURE Generate_XML (p_api_version IN NUMBER, p_init_msg_list IN VARCHAR2, p_validation_level IN NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2, p_ref_cur IN SYS_REFCURSOR, p_row_tag IN VARCHAR2, p_row_set_tag IN VARCHAR2
                            , x_xml_data OUT NOCOPY CLOB);

    -----------------------------------------------------------------------------
    -- Start of comments
    --   API name        : Merge_XML
    --   Type            : Private
    --   Function        : The procedure merges data from two XML objects into a
    --                     single XML object and adds a root tag to the resultant
    --                     XML data.
    --
    --   Pre-reqs        : None.
    --   Parameters      :
    --   IN              :
    --     p_api_version      NUMBER       Required
    --     p_init_msg_list    VARCHAR2     Required
    --     p_validation_level NUMBER       Required
    --     p_xml_src1         CLOB         Required
    --     p_xml_src2         CLOB         Required
    --     p_root_tag         VARCHAR2     Required
    --
    --   OUT             :
    --     x_return_status    VARCHAR2
    --     x_msg_count        NUMBER
    --     x_msg_data         VARCHAR2
    --     x_xml_doc          CLOB
    --
    --   Version : Current version       1.0
    --
    -- End of comments
    -----------------------------------------------------------------------------
    PROCEDURE Merge_XML (p_api_version IN NUMBER, p_init_msg_list IN VARCHAR2, p_validation_level IN NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2, p_xml_src1 IN CLOB, p_xml_src2 IN CLOB, p_root_tag IN VARCHAR2
                         , x_xml_doc OUT NOCOPY CLOB);

    -----------------------------------------------------------------------------
    -- Start of comments
    --   API name        : Print_ClobOutput
    --   Type            : Private
    --   Function        : The procedure writes the XML data to the report output
    --                     file. The XML publisher picks the data from this output
    --                     file to display the data in user specified format.
    --
    --   Pre-reqs        : None.
    --   Parameters      :
    --   IN              :
    --     p_api_version      NUMBER       Required
    --     p_init_msg_list    VARCHAR2     Required
    --     p_validation_level NUMBER       Required
    --     p_xml_data         CLOB
    --
    --   OUT             :
    --     x_return_status    VARCHAR2
    --     x_msg_count        NUMBER
    --     x_msg_data         VARCHAR2
    --
    --   Version : Current version       1.0
    --
    -- End of comments
    -----------------------------------------------------------------------------
    PROCEDURE Print_ClobOutput (p_api_version IN NUMBER, p_init_msg_list IN VARCHAR2, p_validation_level IN NUMBER, x_return_status OUT NOCOPY VARCHAR2, x_msg_count OUT NOCOPY NUMBER, x_msg_data OUT NOCOPY VARCHAR2
                                , p_xml_data IN CLOB);


    --Start Changes for 1.1
    FUNCTION get_usd_conversion (p_currency IN VARCHAR2, p_cutoff_date IN VARCHAR2, p_accrual_amount IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_invoice_age (p_po_header_id IN NUMBER, p_po_line_id IN NUMBER, p_cutoff_date IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_po_preparer (p_po_header_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_rcpt_receiver (p_po_header_id   IN NUMBER,
                                p_po_line_id     IN NUMBER)
        RETURN VARCHAR2;
--End Changes for 1.1

END XXD_BOM_UNINV_RPT_PKG;
/
