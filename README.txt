--------------------------------------------------------------------------------
 Transfer By UV - README

 Transfers Vertex Maps from one mesh to another mesh by matching their
 UV layout. Useful when proportions differ or point order has been broken.

 Website:      http://www.artstorm.net/plugins/transfer-by-uv/
 Project:      http://code.google.com/p/js-lightwave-lscripts/
 Feeds:        http://code.google.com/p/js-lightwave-lscripts/feeds
 
 Contents:
 
 * Installation
 * Usage
 * Source Code
 * Changelog
 * Credits

--------------------------------------------------------------------------------
 Installation
 
 General installation steps:

 * Copy JS_TransferByUV.ls to LightWave’s plug-in folder.
 * If "Autoscan Plugins" is enabled, just restart LightWave and it's installed.
 * Else, locate the “Add Plugins” button in LightWave and add them manually.
 * Tip: To keep things tidy, I personally organize my plugins and scripts in
   folders, so in this case, I'd put the file into
   [LW Install]/Plugins/3rdParty/artstorm/.

 I’d recommend to add the plugin to a convenient spot in LightWave’s menu,
 so all you have to do is press the Transfer by UV button when you need to
 use it. 
 
--------------------------------------------------------------------------------
 Usage

 See http://www.artstorm.net/plugins/transfer-by-uv/ for usage instructions.

--------------------------------------------------------------------------------
 Source Code
 
 Download the source code:
 
   http://code.google.com/p/js-lightwave-lscripts/source/checkout

 You can check out the latest trunk or any previous tagged version via svn
 or explore the repository directly in your browser.
 
 Note that the default checkout path includes all my available LScripts, you
 might want to browse the repository first to get the path to the specific
 script's trunk or tag to download if you don't want to get them all.
 
--------------------------------------------------------------------------------
 Changelog
   
 * v1.2 - 27 Oct 2010
   * Added automatic loading and saving of settings between sessions.
   * Released the script as open source.

 * v1.1 - 1 Apr 2010:
   * Implemented a Weight Interpolation Option.

 * v1.0 - 29 Mar 2010:
   * Release of version 1.0, first public release.   
   
--------------------------------------------------------------------------------
 Credits

 Johan Steen, http://www.artstorm.net/
 * Original author
