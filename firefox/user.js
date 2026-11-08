// Firefox settings, linked into every profile by firefox-setup.sh
// These are applied again on every start, edit them here to change them

// Load firefox/userChrome.css
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Block all AI features
user_pref("browser.ai.control.default", "blocked");
user_pref("browser.ai.control.linkPreviewKeyPoints", "blocked");
user_pref("browser.ai.control.pdfjsAltText", "blocked");
user_pref("browser.ai.control.sidebarChatbot", "blocked");
user_pref("browser.ai.control.smartTabGroups", "blocked");
user_pref("browser.ai.control.smartWindow", "blocked");
user_pref("browser.ai.control.speechRecognition", "blocked");
user_pref("browser.ai.control.translations", "blocked");


// Open a blank page on start
user_pref("browser.startup.homepage", "chrome://browser/content/blanktab.html");

user_pref("browser.toolbars.bookmarks.visibility", "never");

user_pref("sidebar.verticalTabs", true);
user_pref("sidebar.visibility", "hide-sidebar");

user_pref("extensions.activeThemeID", "nova-ash@mozilla.org");

// Toolbar layout, copy from about:config after using Customize Toolbar
user_pref("browser.uiCustomization.state", "{\"placements\":{\"widget-overflow-fixed-list\":[],\"unified-extensions-area\":[\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\"],\"nav-bar\":[\"sidebar-button\",\"back-button\",\"forward-button\",\"customizableui-special-spring1\",\"vertical-spacer\",\"stop-reload-button\",\"urlbar-container\",\"downloads-button\",\"customizableui-special-spring2\",\"reset-pbm-toolbar-button\",\"unified-extensions-button\",\"alltabs-button\",\"smartwindow-group-tabs-button\",\"ai-window-toggle\"],\"TabsToolbar\":[],\"vertical-tabs\":[\"tabbrowser-tabs\"],\"PersonalToolbar\":[\"personal-bookmarks\"]},\"seen\":[\"reset-pbm-toolbar-button\",\"smartwindow-group-tabs-button\",\"ai-window-toggle\",\"developer-button\",\"screenshot-button\",\"ipprotection-button\",\"_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action\"],\"dirtyAreaCache\":[\"nav-bar\",\"TabsToolbar\",\"vertical-tabs\",\"PersonalToolbar\",\"unified-extensions-area\"],\"currentVersion\":28,\"newElementCount\":5}");
