gulp = require 'gulp'
vinyl = require 'vinyl-source-stream'
browserify = require 'browserify'
watchify = require 'watchify'
gutil = require 'gulp-util'
prettyHrtime = require 'pretty-hrtime'
notify = require 'gulp-notify'
mocha = require 'gulp-mocha'
mochaPhantomJS = require 'gulp-mocha-phantomjs'

startTime = null
logger =
  start: ->
    startTime = process.hrtime()
    gutil.log 'Running', gutil.colors.green("'bundle'") + '...'
  end: ->
    taskTime = process.hrtime startTime
    prettyTime = prettyHrtime taskTime
    gutil.log 'Finished', gutil.colors.green("'bundle'"), 'in', gutil.colors.magenta(prettyTime)

handleErrors = ->
  notify.onError
    title: 'Compile error'
    message: '<%= error.message %>'
  .apply this, arguments
  @emit 'end'

build = (test) ->
  [output, entry, options] = if test
    ['tests.js', './test/index', debug: true]
  else
    ['html-docx.js', './src/api', standalone: 'html-docx']

  bundleMethod = if global.isWatching then watchify else browserify
  bundler = bundleMethod
    entries: [entry]
    extensions: ['.coffee']

  bundle = ->
    logger.start()
    bundler
      .bundle options
      .on 'error', handleErrors
      .pipe vinyl(output)
      .pipe gulp.dest('./build')
      .on 'end', logger.end

  if global.isWatching
    bundler.on 'update', bundle

  bundle()

testsBundle = './test/index.coffee'

gulp.task 'setWatch', -> global.isWatching = true
gulp.task 'build', -> build()
gulp.task 'watch', ['setWatch', 'build']

gulp.task 'test-node', (growl = false) ->
  gulp.src(testsBundle, read: false).pipe mocha {reporter: 'spec', growl}
gulp.task 'test-node-watch', ->
  sources = ['src/**', 'test/**']
  gulp.watch sources, ['test-node']

gulp.task 'build-test-browserify', -> build(true)
gulp.task 'run-phantomjs', -> gulp.src('test/testbed.html').pipe(mochaPhantomJS reporter: 'spec')
gulp.task 'test-phantomjs', ['build-test-browserify', 'run-phantomjs']

gulp.task 'default', ['test-node', 'test-node-watch']
