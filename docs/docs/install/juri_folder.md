# JURI Folder Structure

The generated files are put into the folder defined in `$LLVIEW_DATA/$LLVIEW_SYSTEMNAME`.
The subfolders that used for the default steps are:

- `templates`: HandleBars templates to generate pieces of the webpages
- `js`: JavaScript files that are used to generate the website
    - `ext`: External JavaScript libraries
- `css`: CSS stylesheets used
    - `ext`: External CSS libraries
- `utils`: Scripts that can be used in installation and configuration of LLview
- `img`: Images used in the Web Portal
- `config`: Store the base html template used to build the login page
- `json`: Store JSON files that define context of some tabs
- `fonts`: Fonts used on the website

The following files are located in the main folder:

- `login.php`: Login page that is build using PHP after a user has verified login
- `error404.html`: Page to be used when an internal page is not found. It may need to be defined in `.htaccess` file via the `ErrorDocument 404 <folder>/error404.html` configuration
- `index.html`: Main page used to build the portal
- `LICENSE`: GPLv3 License used by JURI
- `README.md`: Basic JURI information
- `CONTRIBUTING.md`: Contributing rules for JURI
- `CITATION.cff`: How to cite JURI
