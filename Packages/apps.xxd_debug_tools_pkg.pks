--
-- XXD_DEBUG_TOOLS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_DEBUG_TOOLS_PKG"
    AUTHID DEFINER
AS
    /****************************************************************************************
    * Package      : XXD_DEBUG_TOOLS_PKG
    * Design       : This package will handle debug log messages
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 05-Mar-2020  1.0        Deckers                 Initial Version
    ******************************************************************************************/

    G_MISS_NUM    CONSTANT NUMBER := 9.99E125;
    G_MISS_CHAR   CONSTANT VARCHAR2 (1) := CHR (0);
    G_MISS_DATE   CONSTANT DATE := TO_DATE ('1', 'j');

    PROCEDURE register_depth (pc_origin VARCHAR2, pn_depth NUMBER);

    PROCEDURE set_origin (pc_origin VARCHAR2 DEFAULT NULL);

    PROCEDURE msg (pc_msg         VARCHAR2,
                   pn_log_level   NUMBER:= 9.99E125,
                   pc_origin      VARCHAR2:= 'Local Debug');

    PROCEDURE set_attributes (pn_attribute_num     IN NUMBER,
                              pc_attribute_value   IN VARCHAR2);

    PROCEDURE clear_attributes;

    PROCEDURE register_controlling_session (pc_instance_name IN VARCHAR2, pc_host_name IN VARCHAR2, pc_username IN VARCHAR2, pc_machine IN VARCHAR2, pc_osuser IN VARCHAR2, pc_process IN VARCHAR2, pn_sid IN NUMBER, pn_serial# IN NUMBER, pn_audsid IN NUMBER, xc_instance_name OUT VARCHAR2, xc_host_name OUT VARCHAR2, xc_username OUT VARCHAR2, xc_machine OUT VARCHAR2, xc_osuser OUT VARCHAR2, xc_process OUT VARCHAR2
                                            , xn_sid OUT NUMBER, xn_serial# OUT NUMBER, xn_audsid OUT NUMBER);

    PROCEDURE register_hosting_session (p_instance_name IN VARCHAR2, p_host_name IN VARCHAR2, p_username IN VARCHAR2, p_machine IN VARCHAR2, p_osuser IN VARCHAR2, p_process IN VARCHAR2, p_sid IN NUMBER, p_serial# IN NUMBER, p_audsid IN NUMBER, p_remote_instance_name IN VARCHAR2, p_remote_host_name IN VARCHAR2, p_remote_username IN VARCHAR2, p_remote_machine IN VARCHAR2, p_remote_osuser IN VARCHAR2, p_remote_process IN VARCHAR2
                                        , p_remote_sid IN NUMBER, p_remote_serial# IN NUMBER, p_remote_audsid IN NUMBER);
END xxd_debug_tools_pkg;
/
