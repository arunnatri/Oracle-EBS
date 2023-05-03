--
-- XXD_ONT_LDAP_UTILS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_LDAP_UTILS_PKG"
AS
    -- ####################################################################################################################
    -- Package      : XXD_ONT_LDAP_UTILS_PKG
    -- Design       : This package will be used to get ad groups
    --
    -- Notes        :
    -- Modification :
    -- ----------
    -- Date            Name                Ver    Description
    -- ----------      --------------      -----  ------------------
    -- 24-MAR-2021    Infosys              1.0    Initial Version

    -- #########################################################################################################################
    l_ldap_host   VARCHAR2 (256) := 'ad.deckers.com';
    l_ldap_port   VARCHAR2 (256) := '389';
    l_ldap_user   VARCHAR2 (256)
        := 'CN=svc-oracle-cloud-sso,OU=Services,OU=Global,DC=corporate,DC=deckers,DC=com';
    l_ldap_base   VARCHAR2 (256) := 'DC=corporate,DC=deckers,DC=com';

    TYPE usr_rec_type IS RECORD
    (
        user_login       VARCHAR2 (50),
        user_fullname    VARCHAR2 (50),
        user_id          VARCHAR2 (50)
    );

    TYPE usr_attr_type IS RECORD
    (
        id       NUMBER (20),
        login    VARCHAR2 (256),
        attr     VARCHAR2 (256),
        val      VARCHAR2 (256)
    );

    TYPE usr_tab_type IS TABLE OF usr_rec_type;

    TYPE usr_tab_attr IS TABLE OF usr_attr_type;

    FUNCTION get_userdata (searchstring IN VARCHAR2)
        RETURN usr_tab_attr
        PIPELINED;
-- procedure write_data (msg IN VARCHAR2);

END XXD_ONT_LDAP_UTILS_PKG;
/
