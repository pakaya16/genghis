{_, Giraffe} = require '../vendors'

Pagination  = require './pagination.coffee'
Servers     = require '../collections/servers.coffee'
Server      = require './server.coffee'
Database    = require './database.coffee'
Collection  = require './collection.coffee'
Document    = require './document.coffee'
Explain     = require './explain.coffee'
Util        = require '../util.coffee'
GenghisJSON = require '../json.coffee'

SERVER_PARAMS     = ['server']
DATABASE_PARAMS   = ['server', 'database']
COLLECTION_PARAMS = ['server', 'database', 'collection']
DOCUMENTS_PARAMS  = ['server', 'database', 'collection', 'query', 'fields', 'sort', 'page', 'explain']
DOCUMENT_PARAMS   = ['server', 'database', 'collection', 'document']

class Selection extends Giraffe.Model
  defaults:
    # Current selection
    server:     null
    database:   null
    collection: null
    document:   null

    # URL query params
    query:      null
    fields:     null
    sort:       null
    page:       null

    # Explain flag
    # TODO: this might not be a good model for the concept. Revisit.
    explain:    false

  dataEvents:
    'change:id change this': 'update'
    # 'change:query change:fields change:sort change:page this': 'updateQuery'

  initialize: ->
    @servers             = new Servers()
    @servers.url         = "#{@baseUrl}servers"
    @server              = new Server()
    @server.collection   = @servers
    @databases           = @server.databases
    @database            = new Database()
    @database.collection = @databases
    @collections         = @database.collections
    @coll                = new Collection()
    @coll.collection     = @collections
    @documents           = @coll.documents
    @document            = new Document()
    @document.collection = @documents
    @explain = new Explain()
    @explain.coll = @coll

  select: (server = null, database = null, collection = null, doc = null, opts = {}) =>
    @set(_.extend(
      {server, database, collection, document: doc},
      _.pick(opts, 'query', 'fields', 'sort', 'page')
    ))

  update: =>
    showErrorMessage = (model, response = {}) ->
      return if response.status is 404
      try
        data = JSON.parse(response.responseText)
      app.alerts.add(msg: data?.error or 'Unknown error', level: 'danger', block: true)

    fetchErrorHandler = (section, notFoundHeading = 'Not Found', notFoundContent = '<p>Please try again.</p>') ->
      (model, response) ->
        switch response.status
          when 404
            app.showNotFound(notFoundHeading, notFoundContent)
          else
            showErrorMessage(model, response)

    changed = @changedAttributes()

    # TODO: fetch servers less often.
    @servers.fetch(reset: true)
      .fail(showErrorMessage)

    if @has('server') and not _.isEmpty(_.pick(changed, SERVER_PARAMS))
      @server.set('id', @get('server'))
      @server.fetch(reset: true)
        .fail(fetchErrorHandler('databases', 'Server Not Found'))

    if @has('database') and not _.isEmpty(_.pick(changed, DATABASE_PARAMS))
      @database.set('id', @get('database'))
      @database.fetch(reset: true)
        .fail(fetchErrorHandler('collections', 'Database Not Found'))

    if @has('collection') and not _.isEmpty(_.pick(changed, COLLECTION_PARAMS))
      @coll.set('id', @get('collection'))
      @coll.fetch(reset: true)
        .fail(fetchErrorHandler('documents', 'Collection Not Found'))

    if @has('document') and not _.isEmpty(_.pick(changed, DOCUMENT_PARAMS))
      @document.set('id', @get('document'))
      @document.fetch(reset: true)
        .fail(fetchErrorHandler(
          'document',
          'Document Not Found',
          '<p>But I&#146;m sure there are plenty of other nice documents out there&hellip;</p>'
        ))

    if @get('explain')
      @explain.fetch()
        .fail(showErrorMessage)

  nextPage: =>
    1 + (@get('page') or 1)

  previousPage: =>
    Math.max(1, (@get('page') or 1) - 1)

  updateQuery: =>
    @query.set(
      query: GenghisJSON.parse(@get('query') || '{}'),
      page:  @get('page')
    )

module.exports = Selection
