# Filter Orderer and Preener

Adjusted for Polish Filters  by [PolishFiltersTeam](https://github.com/PolishFiltersTeam).

A Python program for the automatic sorting of subscription files and parts of subscription files. It is also able to automatically commit the changes to Mercurial repositories and validate comments to ensure that they match the form used in the EasyList repository messages.

FOP offers several advantages over other programs. It can:
- Detect the filter type in sections and sort automatically based on this information.
- Change sorting patterns when switching sections, which are identified by comments.
- Commit automatically and where appropriate.
- Validate commit comments.
- Warn when unrecognised options are used on filters but still sort them alphabetically and append the domain option on the end.
- Automatically make the correct parts of element hiding rules and regular filters lower case.

## Reference
- https://forums.lanik.us/viewtopic.php?p=35541
- https://hg.adblockplus.org/easylist/file/tip/FOP.py
- https://github.com/PolishFiltersTeam/ScriptsPlayground/blob/master/scripts/FOP.py

## License
Copyright (C) 2011 Michael. Licensed under the [GNU General Public License](http://www.gnu.org/licenses/).
