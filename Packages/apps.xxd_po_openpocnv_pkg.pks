--
-- XXD_PO_OPENPOCNV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   XXD_PO_DISTRIBUTIONS_STG_T (Synonym)
--   XXD_PO_HEADERS_STG_T (Synonym)
--   XXD_PO_LINES_STG_T (Synonym)
--   XXD_PO_LINE_LOCATIONS_STG_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_PO_OPENPOCNV_PKG
AS
    -- +==============================================================================+
    -- +                      Deckers Oracle 12i                                      +
    -- +==============================================================================+
    -- |                                                                              |
    -- |CVS ID:   1.1                                                                 |
    -- |Name: BT Technology Team                                                      |
    -- |Creation Date: 18-AUG-2014                                                    |
    -- |Application Name:  Custom Application                                         |
    -- |Source File Name: XXD_PO_OPENPOCNV_PKG.pks                                |
    -- |                                                                              |
    -- |Object Name :   XXD_PO_OPENPOCNV_PKG                                       |
    -- |Description   : The package Spac is defined to convert the                    |
    -- |                in R12                                                        |
    -- |                                                                              |
    -- |Usage:                                                                        |
    -- |                                                                              |
    -- |Parameters   :      p_action         -- Action Type                           |
    -- |                p_batch_cnt      -- Batch Count                               |
    -- |                p_batch_size     -- Batch Size                                |
    -- |                p_debug          -- Debug Flag                                |
    -- |                                                                              |
    -- |                                                                              |
    -- |                                                                              |
    -- |Change Record:                                                                |
    -- |===============                                                               |
    -- |Version   Date             Author             Remarks                         |
    -- |=======   ==========  ===================   ============================      |
    -- |1.0       18-AUG-2014  BT Technology Team     Initial draft version           |
    -- +==============================================================================+

    -- Global variables
    gd_sys_date                     DATE := SYSDATE;
    gn_conc_request_id              NUMBER := fnd_global.conc_request_id;
    gn_user_id                      NUMBER := fnd_global.user_id;
    gn_login_id                     NUMBER := fnd_global.login_id;
    gn_parent_request_id            NUMBER;
    gc_xxdo                CONSTANT VARCHAR2 (10) := 'XXDCONV';
    gc_program_shrt_name   CONSTANT VARCHAR2 (10) := 'POXPOPDOI';
    gc_appl_shrt_name      CONSTANT VARCHAR2 (10) := 'PO';
    gc_standard_type       CONSTANT VARCHAR2 (10) := 'STANDARD';
    gc_approved            CONSTANT VARCHAR2 (10) := 'APPROVED';
    gc_update_create       CONSTANT VARCHAR2 (2) := 'N';
    gc_no_flag             CONSTANT VARCHAR2 (10) := 'N';
    gc_yes_flag            CONSTANT VARCHAR2 (10) := 'Y';
    gn_batch_size                   NUMBER;
    gc_debug_flag                   VARCHAR2 (10);
    gc_debug_msg                    VARCHAR2 (4000);
    null_data                       EXCEPTION;
    gn_request_id                   NUMBER := NULL;
    gn_application_id               NUMBER := FND_GLOBAL.RESP_APPL_ID; --this stores application id
    gn_responsibility_id            NUMBER := FND_GLOBAL.RESP_ID; --this stores responsibility id
    gn_org_id                       NUMBER := FND_GLOBAL.org_id;


    gn_suc_const           CONSTANT NUMBER := 0;
    gn_warn_const          CONSTANT NUMBER := 1;
    gn_err_const           CONSTANT NUMBER := 2;

    /* gc_validate_status       CONSTANT VARCHAR2(20) :='VALIDATED';
     gc_error_status          CONSTANT VARCHAR2(20) :='ERROR';
     gc_new_status            CONSTANT VARCHAR2(20) :='NEW';
     gc_process_status        CONSTANT VARCHAR2(20) :='PROCESSED';
     gc_interfaced            CONSTANT VARCHAR2(20) :='INTERFACED';
     */
    gc_validate_status     CONSTANT VARCHAR2 (20) := 'V';
    gc_error_status        CONSTANT VARCHAR2 (20) := 'E';
    gc_new_status          CONSTANT VARCHAR2 (20) := 'N';
    gc_process_status      CONSTANT VARCHAR2 (20) := 'P';
    gc_interfaced          CONSTANT VARCHAR2 (20) := 'I';

    gc_extract_only        CONSTANT VARCHAR2 (20) := 'EXTRACT'; --'EXTRACT ONLY';
    gc_validate_only       CONSTANT VARCHAR2 (20) := 'VALIDATE'; -- 'VALIDATE ONLY';
    gc_load_only           CONSTANT VARCHAR2 (20) := 'LOAD';    --'LOAD ONLY';


    -- Global tables
    TYPE gtab_rec_req_rec IS RECORD
    (
        req_id      NUMBER,
        rec_low     NUMBER,
        rec_high    NUMBER
    );

    TYPE gtab_rec_req IS TABLE OF gtab_rec_req_rec
        INDEX BY BINARY_INTEGER;

    TYPE gtab_imp_req_rec IS RECORD
    (
        req_id    NUMBER
    );

    TYPE gtab_imp_req IS TABLE OF gtab_imp_req_rec
        INDEX BY BINARY_INTEGER;

    TYPE gtab_po_header IS TABLE OF XXD_PO_HEADERS_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE gtab_po_line IS TABLE OF XXD_PO_LINES_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;


    TYPE gtab_po_loc IS TABLE OF XXD_PO_LINE_LOCATIONS_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE gtab_po_dist IS TABLE OF XXD_PO_DISTRIBUTIONS_STG_T%ROWTYPE
        INDEX BY BINARY_INTEGER;

    TYPE gtab_request_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    TYPE gt_concurrent_req_id IS TABLE OF NUMBER
        INDEX BY BINARY_INTEGER;

    -- +===================================================================+
    -- | Name  : OPEN_PO_MAIN                                              |
    -- | Description      : This is the main procedure which will call     |
    -- |                    the child program to validate and populate the |
    -- |                        data into oracle purchase order base tables|
    -- |                                                                   |
    -- | Parameters : p_action, p_batch_size, p_debug, pa_batch_size       |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :   x_errbuf, x_retcode                                   |
    -- |                                                                   |
    -- +===================================================================+
    PROCEDURE OPEN_PO_MAIN (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, p_org_name IN VARCHAR2, p_scenario IN VARCHAR2, p_action IN VARCHAR2, p_batch_cnt IN NUMBER
                            --       ,p_batch_size     IN NUMBER
                            , p_debug IN VARCHAR2 DEFAULT 'N');

    -- +===================================================================+
    -- | Name  : OPEN_PO_CHILD_PRC                                         |
    -- | Description      : This procedure is used to process              |
    -- |                    the purchase order staging data in batches     |
    -- |                                                                   |
    -- | Parameters : p_batch_id, p_action,                                |
    -- |              p_debug_flag, p_parent_req_id                        |
    -- |                                                                   |
    -- |                                                                   |
    -- | Returns :   x_errbuf, x_retcode                                   |
    -- |                                                                   |
    -- +===================================================================+
    PROCEDURE open_po_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_org_name IN VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_batch_id IN NUMBER
                             , p_parent_request_id IN NUMBER);
END XXD_PO_OPENPOCNV_PKG;
/
