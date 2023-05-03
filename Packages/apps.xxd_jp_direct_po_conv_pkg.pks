--
-- XXD_JP_DIRECT_PO_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   FND_PROFILE (Package)
--   XXD_COMMON_UTILS (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_JP_DIRECT_PO_CONV_PKG
AS
    gn_user_id                     NUMBER := fnd_global.user_id;
    gn_resp_id                     NUMBER := fnd_global.resp_id;
    gn_resp_appl_id                NUMBER := fnd_global.resp_appl_id;
    gn_req_id                      NUMBER := fnd_global.conc_request_id;
    gn_sob_id                      NUMBER := fnd_profile.VALUE ('GL_SET_OF_BKS_ID');
    gn_org_id                      NUMBER := XXD_common_utils.get_org_id;
    gn_login_id                    NUMBER := fnd_global.login_id;

    gd_sysdate                     DATE := SYSDATE;
    gc_code_pointer                VARCHAR2 (500);
    gn_limit              CONSTANT NUMBER := 500;
    gc_new_record         CONSTANT VARCHAR2 (1) := 'N';
    gc_valid_record       CONSTANT VARCHAR2 (1) := 'V';
    gc_processed_record   CONSTANT VARCHAR2 (1) := 'P';
    gc_error_record       CONSTANT VARCHAR2 (1) := 'E';
    gc_yes_flag           CONSTANT VARCHAR2 (1) := 'Y';
    gc_no_flag            CONSTANT VARCHAR2 (1) := 'N';
    gc_debug_flag                  VARCHAR2 (1) := 'Y';



    PROCEDURE get_internal_req_extract_prc (x_retcode   OUT NUMBER,
                                            x_errbuf    OUT VARCHAR2);

    PROCEDURE MAIN (x_retcode OUT NUMBER, x_errbuf OUT VARCHAR2, p_process IN VARCHAR2
                    , p_debug IN VARCHAR2);

    PROCEDURE VALIDATE_REQUISITION_PRC (x_retcode   OUT NUMBER,
                                        x_errbuff   OUT VARCHAR2);
 /*  PROCEDURE INTERFACE_REQUISITION_PROC (x_retcode       OUT NUMBER,
                                         x_errbuff       OUT VARCHAR2,
                                         p_batch_no   IN     NUMBER,
                                         p_debug      IN     VARCHAR2,
                     p_scenario        IN     VARCHAR2);

   PROCEDURE CREATE_PROGRESS_ORDER (x_retcode   OUT NUMBER,
                                    x_errbuf    OUT VARCHAR2,
                                    p_scenario        IN     VARCHAR2);

   PROCEDURE XXD_AUTOCREATE_PO_TRADE (P_ERRBUF       OUT NOCOPY VARCHAR2,
                                      P_RETCODE      OUT NOCOPY NUMBER
                                      ,p_scenario        IN     VARCHAR2);
   PROCEDURE XXD_ORDER_IMPORT (P_ERRBUF       OUT NOCOPY VARCHAR2,
                                      P_RETCODE      OUT NOCOPY NUMBER
                                   ,p_scenario        IN     VARCHAR2    );
PROCEDURE CALL_ORDER_IMPORT (P_ERRBUF       OUT NOCOPY VARCHAR2,
                                     P_RETCODE      OUT NOCOPY NUMBER
                                     , p_scenario        IN     VARCHAR2);
 PROCEDURE CALL_REQUISITION_IMPORT(P_ERRBUF       OUT NOCOPY VARCHAR2,
                                      P_RETCODE      OUT NOCOPY NUMBER,
                                       P_BATCH_ID  IN NUMBER);
 PROCEDURE UPDATE_ORDER_ATTRIBUTE (P_ERRBUF       OUT NOCOPY VARCHAR2,
                    P_RETCODE      OUT NOCOPY NUMBER
                    ,p_scenario        IN     VARCHAR2);
         */



END XXD_JP_DIRECT_PO_CONV_PKG;
/
