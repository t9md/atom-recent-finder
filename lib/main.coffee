{CompositeDisposable} = require 'atom'
fs = require 'fs-plus'
_  = require 'underscore-plus'

requireFromPackage = (packageName, fileName) ->
  path = require 'path'
  packageRoot = atom.packages.resolvePackagePath(packageName)
  filePath = path.join(packageRoot, 'lib', fileName)
  require(filePath)

FuzzyFinderView = requireFromPackage('fuzzy-finder', 'fuzzy-finder-view')

# Hisotry management
# -------------------------
class History
  add: (filePath) ->
    items = @getAllItems()
    items.unshift(filePath)
    items = _.uniq(items)
    items.splice(atom.config.get('recent-finder.max'))
    @saveItems(items)

  getAllItems: ->
    if items = localStorage['recent-finder']
      try
        _.filter(JSON.parse(items), (item) -> fs.existsSync(item))
      catch
        []
    else
      []

  clear: ->
    @saveItems(undefined)

  saveItems: (items) ->
    localStorage['recent-finder'] = JSON.stringify(items)

# View
# -------------------------
class View extends FuzzyFinderView
  toggle: (items) ->
    if @panel?.isVisible()
      @cancel()
    else
      @setItems(items)
      @show()

  getEmptyMessage: (itemCount) ->
    if itemCount is 0
      'No file opend recently'
    else
      super

# Utility
# -------------------------
notifyAndDeleteSettings = (scope, params...) ->
  hasParam = (param) ->
    param of atom.config.get(scope)

  paramsToDelete = (param for param in params when hasParam(param))
  return if paramsToDelete.length is 0

  content = [
    "#{scope}: Config options deprecated.  ",
    "Automatically removed from your `connfig.cson`  "
  ]

  for param in paramsToDelete
    atom.config.set("#{scope}.#{param}", undefined)
    content.push "- `#{param}`"
  atom.notifications.addWarning(content.join("\n"), dismissable: true)

# Main
# -------------------------
module.exports =
  history: null
  config:
    max:
      type: 'integer'
      default: 50
      minimum: 1
      description: "Max number of files to remember"

  activate: ->
    notifyAndDeleteSettings('recent-finder', 'syncImmediately')

    @history = new History
    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.workspace.onDidOpen ({item}) =>
      @history.add(filePath) if filePath = item.getPath?()

    @subscriptions.add atom.commands.add 'atom-workspace',
      'recent-finder:toggle': => @getView().toggle(@history.getAllItems())
      'recent-finder:clear': => @history.clear()

  deactivate: ->
    @view?.destroy()
    @subscriptions.dispose()
    {@view, @subscriptions, @entries} = {}

  # I can't depend on serialize/desilialize since its per-project based.
  # serialize: ->

  getView:  ->
    @view ?= new View
