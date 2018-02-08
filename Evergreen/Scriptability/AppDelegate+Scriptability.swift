//
//  AppDelegate+Scriptability.swift
//  Evergreen
//
//  Created by Olof Hellman on 2/7/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

/*
    Note:  strictly, the AppDelegate doesn't appear as part of the scripting model,
    so this file is rather unlike the other Object+Scriptability.swift files.
    However, the AppDelegate object is the de facto scripting accessor for some
    application elements and properties.  For, example, the main window is accessed
    via the AppDelegate's MainWindowController, and the main window itself has
    selected feeds, selected articles and a current article.  This file supplies the glue to access
    these scriptable objects, while being completely separate from the core AppDelegate code,
*/

import Foundation
import Data

protocol ScriptingAppDelegate {
    var  scriptingCurrentArticle: Article?  {get}
    var  scriptingSelectedArticles: [Article]  {get}
    var  scriptingMainWindowController:ScriptingMainWindowController? {get}
}


