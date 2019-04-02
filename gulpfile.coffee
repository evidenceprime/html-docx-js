gulp = require 'gulp'
vinyl = require 'vinyl-source-stream'
browserify = require 'browserify'
watchify = require 'watchify'
gutil = require 'gulp-util'
prettyHrtime = require 'pretty-hrtime'
notify = require 'gulp-notify'
mocha = require 'gulp-mocha'
mochaPhantomJS = require 'gulp-mocha-phantomjs'
template = require 'gulp-lodash-template'
coffee = require 'gulp-coffee'
del = require 'del'
uglify = require 'gulp-uglify'
fsExtra = require 'fs-extra'
pipeline = require('readable-stream').pipeline
walkSync = require 'klaw-sync'
path = require 'path'

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
    extensions: ['.coffee', '.tpl']

  bundle = ->
    logger.start()
    bundler
      .transform 'jstify', engine: 'lodash-micro', minifierOpts: false
      .bundle options
      .on 'error', handleErrors
      .pipe vinyl(output)
      .pipe gulp.dest('./build')
      .on 'end', logger.end

  if global.isWatching
    bundler.on 'update', bundle

  bundle()

testsBundle = './test/index.coffee'

clean = (cb) -> del 'build', cb

gulp.task 'clean', clean
gulp.task 'setWatch', -> global.isWatching = true
gulp.task 'build', -> build()
gulp.task 'watch', ['setWatch', 'build']

minify = ->
  builtFile = './build/html-docx.js'
  entry = './build/html-docx.min.js'
  dest = './build'
  fsExtra.copySync builtFile, entry
  pipeline(
    gulp.src(entry),
    uglify(),
    gulp.dest(dest)
  )
gulp.task 'minify', minify

buildNode = (compileCoffee = true) ->
  logger.start()
  gulp.src('src/**/*', base: 'src').pipe(gulp.dest('build'))
  gulp.src('src/templates/*.tpl').pipe(template commonjs: true).pipe(gulp.dest('build/templates'))
  if compileCoffee
    gulp.src('src/**/*.coffee').pipe(coffee bare: true)
      .on('error', handleErrors).on('end', logger.end).pipe(gulp.dest('build'))
  else
    logger.end()

gulp.task 'build-node', buildNode
gulp.task 'test-node', (growl = false) ->
  buildNode(false)
  gulp.src(testsBundle, read: false).pipe mocha {reporter: 'spec', growl}
gulp.task 'test-node-watch', ->
  sources = ['src/**', 'test/**']
  gulp.watch sources, ['test-node']

gulp.task 'build-test-browserify', -> build(true)
gulp.task 'run-phantomjs', -> gulp.src('test/testbed.html').pipe(mochaPhantomJS reporter: 'spec')
gulp.task 'test-phantomjs', ['build-test-browserify', 'run-phantomjs']

cleanRelease = (cb) ->
  del 'dist', cb

copyRelease = ->
  jsFilesFilterFn = (item) ->
    item.path.indexOf('.js') is item.path.length - '.js'.length

  fsExtra.copySync './build/assets', './dist/node/assets'
  templateFiles = walkSync './build/templates', filter: jsFilesFilterFn, noDir: true
  templateFiles.forEach ({ path: filePath }) ->
    fileName = path.basename(filePath)
    fsExtra.copySync filePath, "./dist/node/templates/#{fileName}"
  jsFiles = walkSync './build', filter: jsFilesFilterFn, noDir: true
  jsFiles.forEach ({ path: filePath }) ->
    fileName = path.basename(filePath)
    outputPath = if fileName.indexOf('html-docx') isnt 0 then './dist/node' else './dist'
    fsExtra.copySync filePath, "#{outputPath}/#{fileName}"

gulp.task 'clean-release', cleanRelease
gulp.task 'copy-release', copyRelease

gulp.task 'default', ['test-node', 'test-node-watch']
