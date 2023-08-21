import Foundation

public class Story: Object {
    
    /// The current version of the ink story file format.
    public let inkVersionCurrent = 21
    
    /**
     Version numbers are for engine itself and story file, rather
     than the story state save format
      - old engine, new format: always fail
      - new engine, old format: possibly cope, based on this number
     When incrementing the version number above, the question you
     should ask yourself is:
      - Will the engine be able to load an old story file from
        before I made these changes to the engine?
        If possible, you should support it, though it's not as
        critical as loading old save games, since it's an
        in-development problem only.
     */
    
    /// The minimum legacy version of ink that can be loaded by the current version of the code.
    public let inkVersionMinimumCompatible = 18;
    
    /**
     The list of `Choice` objects available at the current point in
     the `Story`. This list will be populated as the `Story` is stepped
     through with the `Continue()` method. Once `canContinue` becomes
     `false`, this list will be populated, and is usually
     (but not always) on the final `Continue()` step.
     */
    public var currentChoices: [Choice] {
        // Don't include invisible choices for external usage.
        var choices: [Choice] = []
        for c in _state.currentChoices {
            if !(c.isInvisibleDefault ?? false) {
                c.index = choices.count
                choices.append(c)
            }
        }
        return choices
    }
    
    /// The latest line of text to be generated from a `Continue()` call.
    public var currentText: String {
        state.currentText
    }
    

    /// Gets a list of tags as defined with `'#'` in source that were seen
    /// during the latest `Continue()` call.
    public var currentTags: [String] {
        return state.currentTags
    }
    
    /// Any errors generated during evaluation of the `Story`.
    public var currentErrors: [String] {
        state.currentErrors
    }
    
    /// Any warnings generated during evaluation of the `Story`.
    public var currentWarnings: [String] {
        state.currentWarnings
    }
    
    /// The current flow name if using multi-flow functionality - see `SwitchFlow`
    public var currentFlowName: String {
        state.currentFlowName
    }
    
    /// Is the default flow currently active? By definition, will also
    /// return `true` if not using multi-flow functionality - see `SwitchFlow`
    public var currentFlowIsDefaultFlow: Bool {
        state.currentFlowIsDefaultFlow
    }
    
    /// Names of currently alive flows (not including the default flow)
    public var aliveFlowNames: [String] {
        state.aliveFlowNames
    }
    
    /// Whether the `currentErrors` list contains any errors.
    /// THIS MAY BE REMOVED - you should be setting an error handler directly
    /// using `Story.onError`.
    public var hasError: Bool {
        state.hasError
    }
    
    /// Whether the `currentWarnings` list contains any warnings.
    public var hasWarning: Bool {
        state.hasWarning
    }
    
    /// The `VariablesState` object contains all the global variables in the story.
    /// However, note that there's more to the state of a `Story` than just the
    /// global variables. This is a convenience accessor to the full state object.
    public var variablesState: VariablesState {
        state.variablesState!
    }
    
    public var listDefinitions: ListDefinitionsOrigin? {
        _listDefinitions
    }
    
    /// The entire current state of the story including (but not limited to):
    /// - Global variables
    /// - Temporary variables
    /// - Read/visit and turn counts
    /// - The callstack and evaluation stacks
    /// - The current threads
    public var state: StoryState {
        _state
    }
    
    /// Error handler for all runtime errors in ink - i.e. problems
    /// with the source ink itself that are only discovered when playing
    /// the story.
    ///
    /// It's strongly recommended that you assign an error handler to your
    /// story instance to avoid getting exceptions for ink errors.
    public var onError: [ErrorHandler] = []
    
    /// Callback for when `ContinueInterval` is complete
    public var onDidContinue: [() -> Void] = []
    
    /// Callback for when a choice is about to be executed
    public var onMakeChoice: [(Choice) -> Void] = []
    
    /// Callback for when a function is about to be evaluated
    public var onEvaluateFunction: [(String, [Any?]) -> Void] = []
    
    /// Callback for when a function has been evaluated.
    /// This is necessary because evaluating a function can cause continuing.
    public var onCompleteEvaluateFunction: [(String, [Any?], String, Any?) -> Void] = []
    
    /// Callback for when a path string is chosen.
    public var onChoosePathString: [(String, [Any?]) -> Void] = []
    
    /// Start recording ink profiling information during calls to `Continue()` on this story.
    /// - Returns: a `Profiler` instance that you can request a report from when you're finished.
    public func StartProfiling() -> Profiler {
        IfAsyncWeCant("start profiling")
        _profiler = Profiler()
        return _profiler!
    }
    
    /// Stop recording ink profiling information during calls to `Continue()` on this story.
    public func EndProfiling() {
        _profiler = nil
    }
    
    
    /// Creates a new `Story` with the given content container and list definitions.
    ///
    /// When creating a `Story` using this constructor, you need to
    /// call `ResetState()` on it before use. Intended for compiler use only.
    /// For normal use, use the constructor that takes a JSON string.
    public init(_ contentContainer: Container?, _ lists: [ListDefinition]? = nil) {
        _mainContentContainer = contentContainer
        
        if lists != nil {
            _listDefinitions = ListDefinitionsOrigin(lists!)
        }
        
        _externals = [:]
    }
    
    /// Construct a `Story` object using a JSON string compiled with inklecate.
    /// - Parameter jsonString: The JSON string generated with inklecate.
    public convenience init(_ jsonString: String) throws {
        self.init(nil)
        
        // TODO: Swift should be able to handle this well!
        var rootObject: [String: Any?] = SimpleJson.TextToDictionary(jsonString)
        
        guard let formatFromFile = rootObject["inkVersion"] as? Int else {
            throw StoryError.inkVersionNotFound
        }
        
        if formatFromFile > inkVersionCurrent {
            throw StoryError.storyInkVersionIsNewer
        }
        else if formatFromFile < inkVersionMinimumCompatible {
            throw StoryError.storyInkVersionTooOld
        }
        else if formatFromFile != inkVersionCurrent {
            print("Warning: Version of ink used to build story doesn't match current version of engine. Non-critical, but recommend synchronising.")
        }
        
        var rootToken = rootObject["root"]
        if rootToken == nil {
            throw StoryError.rootNodeNotFound
        }
        
        if let listDefsObj = rootObject["listDefs"] {
            _listDefinitions = Json.JTokenToListDefinitions(listDefsObj)
        }
        
        _mainContentContainer = Json.JTokenToRuntimeObject(rootToken) as! Container
        
        ResetState()
    }
    
    // TODO: Complete!
    /// Returns a JSON string representing the story itself.
    public func ToJson() -> String {
        return ""
    }
    
    // TODO: Complete!
    /// Writes a JSON string representing the story itself to a stream.
    public func ToJson(_ stream: Stream) {
        
    }
    
    // TODO: Complete!
    func ToJson(_ writer: JSONEncoder) {
        
    }
    
    /// Reset the story back to its initial state as it was when it was first constructed.
    public func ResetState() {
        // TODO: Could make this possible
        IfAsyncWeCant("ResetState")
        
        _state = StoryState(self)
        _state.variablesState?.variableChangedEvent += VariableStateDidChangeEvent
        
        ResetGlobals()
    }
    
    func ResetErrors() {
        _state.ResetErrors()
    }
    
    /// Unwinds the callstack.
    ///
    /// Useful to reset the story's evaluation without actually changing any
    /// meaningful state, for example if you want to exit a section of story
    /// prematurely and tell it to go elsewhere with a call to `ChoosePathString()`.
    /// Doing so without calling `ResetCallstack()` could cause unexpected
    /// issues if, for example, the story was in a tunnel already.
    public func ResetCallstack() {
        IfAsyncWeCant("ResetCallstack")
        _state.ForceEnd()
    }
    
    func ResetGlobals() {
        if _mainContentContainer?.namedContent.keys.contains("global decl") ?? false {
            var originalPointer = state.currentPointer
            
            ChoosePath(Path("global decl"), incrementingTurnIndex: false)
            
            // Continue, but without validating external bindings,
            // since we may be doing this reset at initialisation time.
            ContinueInternal()
            
            state.currentPointer = originalPointer
        }
        
        state.variablesState?.SnapshotDefaultGlobals()
    }
    
    public func SwitchFlow(_ flowName: String) throws {
        IfAsyncWeCant("switch flow")
        if _asyncSaving {
            throw StoryError.cannotSwitchFlowDueToBackgroundSavingMode(flowName: flowName)
        }
        state.SwitchFlow_Internal(flowName)
    }
    
    public func RemoveFlow(_ flowName: String) throws {
        try state.RemoveFlow_Internal(flowName)
    }
    
    /// Continue the story for one line of content, if possible.
    ///
    /// If you're not sure if there's more content available (for example if you
    /// want to check whether you're at a choice point or the end of the story),
    /// you should call `canContinue` before calling this function.
    /// - Returns: The next line of text content.
    public func Continue() -> String {
        ContinueAsync(0)
        return currentText
    }
    
    /// Check whether more content would be available if you were to call `Continue()` - i.e.
    /// are we mid-story rather than at a choice point or an end.
    public var canContinue: Bool {
        state.canContinue
    }
    
    /// If `ContinueAsync()` was called (with milliseconds limit > 0) then this property
    /// will return `false` if the ink evaluation isn't yet finished, and you need to call
    /// it again in order for the `Continue()` to fully complete.
    public var asyncContinueComplete {
        return !_asyncContinueActive
    }
    
    /// An "asynchronous" version of `Continue()` that only partially evaluates the ink,
    /// with a budget of a certain time limit. It will exit ink evaluation early if
    /// the evaluation isn't complete within the time limit, with the
    /// `asyncContinueComplete` property being `false`.
    /// This is useful if ink evaluation takes a long time, and you want to distribute
    /// it over multiple game frames for smoother animation.
    /// If you pass a limit of zero, then it will fully evaluate the ink in the same
    /// way as calling `Continue()` (and, in fact, this is exactly what `Continue()` does internally).
    public func ContinueAsync(_ millisecsLimitAsync: Float) {
        if !_hasValidatedExternals {
            ValidateExternalBindings()
        }
        ContinueInternal(millisecsLimitAsync)
    }
    
    
    func ContinueInternal(_ millisecsLimitAsync: Float = 0.0) throws {
        _profiler?.PreContinue()
        
        var isAsyncTimeLimited = millisecsLimitAsync > 0
        
        _recursiveContinueCount += 1
        
        // Doing either:
        // - full run through non-async (so not active and don't want to be)
        // - Starting async run-through
        if !_asyncContinueActive {
            _asyncContinueActive = isAsyncTimeLimited
            
            if !canContinue {
                throw StoryError.cannotContinue
            }
            
            _state.didSafeExit = false
            _state.ResetOutput()
            
            // It's possible for ink to call game to call ink to call game etc
            // In this case, we only want to batch observe variable changes
            // for the outermost call
            if _recursiveContinueCount == 1 {
                _state.variablesState?.batchObservingVariableChanges = true
            }
        }
        
        // Start timing
        var durationStopwatch = Stopwatch()
        durationStopwatch.Start()
        
        var outputStreamEndsInNewline = false
        _sawLookaheadUnsafeFunctionAfterNewline = false
        repeat {
            do {
                outputStreamEndsInNewline = ContinueSingleStep()
            }
            catch {
                AddError(e)
                break
            }
            
            if outputStreamEndsInNewline {
                break
            }
                
            // Run out of async time?
            if _asyncContinueActive && durationStopwatch.elapsedTime > (Double(millisecsLimitAsync) / 1000.0) {
                break
            }
        } while canContinue
        
        durationStopwatch.Stop()
        
        // 4 outcomes:
        // - got newline (so finished this line of text)
        // - can't continue (e.g. choices or ending)
        // - ran out of time during evaluation
        // - error
        
        // Successfully finished evaluation in time (or in error)
        if outputStreamEndsInNewline || !canContinue {
            // Need to rewind, due to evaluating further than we should?
            if _stateSnapshotAtLastNewline != nil {
                RestoreStateSnapshot()
            }
            
            // Finished a section of content / reached a choice point?
            if !canContinue {
                if state.callStack.canPopThread {
                    AddError("Thread available to pop, threads should always be flat by the end of evaluation?")
                }
                
                if state.generatedChoices.count == 0 && !state.didSafeExit && _temporaryEvaluationContainer == nil {
                    if state.callStack.CanPop(.Tunnel) {
                        AddError("unexpectedly reached end of content. Do you need a '->->' to return from a tunnel?")
                    }
                    else if state.callStack.CanPop(.Function) {
                        AddError("unexpectedly reached end of content. Do you need to add '~ return' to your script?")
                    }
                    else if !state.callStack.canPop {
                        AddError("ran out of content. Do you need to add '-> DONE' or '-> END' to your script?")
                    }
                    else {
                        AddError("unexpectedly reached end of content for unknown reason. Please debug compiler!")
                    }
                }
            }
            
            state.didSafeExit = false
            _sawLookaheadUnsafeFunctionAfterNewline = false
            
            if _recursiveContinueCount == 1 {
                _state.variablesState?.batchObservingVariableChanges = false
            }
            
            _asyncContinueActive = false
            onDidContinue.Invoke()
        }
        
        _recursiveContinueCount -= 1
        
        _profiler?.PostContinue()
        
        // Report any errors that occurred during evaluation.
        // This may either have been StoryErrors that were thrown
        // and caught during evaluation, or directly added with AddError().
        if state.hasError || state.hasWarning {
            if onError.isEmpty {
                if state.hasError {
                    for err in state.currentErrors {
                        onError.Invoke(err, .error)
                    }
                }
                
                if state.hasWarning {
                    for err in state.currentWarnings {
                        onError.Invoke(err, .warning)
                    }
                }
                
                ResetErrors()
            }
            // Throw an exception since there's no error handler
            else {
                var sb = ""
                sb += "Ink had "
                if state.hasError {
                    sb += "\(state.currentErrors.count) \(state.currentErrors.count == 1 ? "error" : "errors")"
                    if state.hasWarning {
                        sb += " and "
                    }
                }
                
                if state.hasWarning {
                    sb += "\(state.currentWarnings.count) \(state.currentWarnings.count == 1 ? "warning" : "warnings")"
                }
                sb += ". It is strongly suggested that you assign an error handler to story.onError. The first issue was: "
                sb += state.hasError ? state.currentErrors[0] : state.currentWarnings[0]
                
                // If you get this exception, please assign an error handler to your story.
                throw StoryError.errorsOnContinue(sb)
            }
        }
    }
    
    func ContinueSingleStep() -> Bool {
        _profiler?.PreStep()
        
        // Run main step function (walks through content)
        Step()
        
        _profiler?.PostStep()
        
        // Run out of content and we have a default invisible choice that we can follow?
        if !canContinue && !state.callStack.elementIsEvaluateFromGame {
            TryFollowDefaultInvisibleChoice()
        }
        
        _profiler?.PreSnapshot()
        
        // Don't save/rewind during string evaluation, which is e.g. used for choices
        if !state.inStringEvaluation {
            // We previously found a newline, but were we just double checking that
            // it wouldn't immediately be removed by glue?
            if _stateSnapshotAtLastNewline != nil {
                // Has proper text or a tag been added? Then we know that the newline
                // that was previously added is definitely the end of the line.
                var change = CalculateNewlineOutputStateChange(_stateSnapshotAtLastNewline!.currentText, state.currentText, _stateSnapshotAtLastNewline!.currentTags.count, state.currentTags.count)
                
                // The last time we saw a newline, it was definitely the end of the line, so we
                // want to rewind to that point.
                if change == .extendedBeyondNewline || _sawLookaheadUnsafeFunctionAfterNewline {
                    RestoreStateSnapshot()
                    
                    // Hit a newline for sure, we're done
                    return true
                }
                
                // Newline that previously existed is no longer valid - e.g.
                // glue was encountered that caused it to be removed
                else if change == .newlineRemoved {
                    DiscardSnapsot()
                }
            }
            
            // Current content ends in a newline - approaching end of our evaluation
            if state.outputStreamEndsInNewLine {
                // If we can continue evaluation for a bit:
                // Create a snapshot in case we need to rewind.
                // We're going to continue stepping in case we see glue or some
                // non-text content such as choices.
                if canContinue {
                    // Don't bother to record the state beyond the current newline.
                    // e.g.:
                    // Hello world\n           // record state at the end of here
                    // ~ complexCalculation()  // don't actually need this unless it generates text
                    if _stateSnapshotAtLastNewline == nil {
                        StateSnapshot()
                    }
                }
                
                // Can't continue, so we're about to exit - make sure we
                // don't have an old state hanging around
                else {
                    DiscardSnapshot()
                }
            }
        }
        
        _profiler?.PostSnapshot()
        
        return false
    }
    
    // Assumption: prevText is the snapshot where we saw a newline, and we're checking whether we're really done
    // with that line. Therefore prevText will definitely end in a newline.
    //
    // We take tags into account too, so that a tag following a content line:
    //   Content
    //   # tag
    // ...doesn't cause the tag to be wrongly associated with the content above.
    enum OutputStateChange {
        case noChange
        case extendedBeyondNewline
        case newlineRemoved
    }
    
    func CalculateNewlineOutputStateChange(_ prevText: String, _ currText: String, _ prevTagCount: Int, _ currTagCount: Int) -> OutputStateChange {
        // Simple case: nothing's changed, and we still have a newline
        // at the end of the current content
        var currTextArray = Array(currText.unicodeScalars)
        
        var newlineStillExists = currText.count >= prevText.count && prevText.count > 0 && currTextArray[prevText.count - 1] == "\n"
        if prevTagCount == currTagCount && prevText.count == currText.count && newlineStillExists {
            return .noChange
        }
        
        // Old newline has been removed, it wasn't the end of the line after all
        if !newlineStillExists {
            return .newlineRemoved
        }
        
        // Tag added - definitely the start of a new line
        if currTagCount > prevTagCount {
            return .extendedBeyondNewline
        }
        
        // There must be new content - check whether it's just whitespace
        for i in prevText.count ..< currText.count {
            var c = currTextArray[i]
            if c != " " && c != "\t" {
                return .extendedBeyondNewline
            }
        }
        
        // There's new text but it's just spaces and tabs, so there's still the potential
        // for glue to kill the newline
        return .noChange
    }
    
    /// Continue the story until the next choice point or until it runs out of content.
    ///
    /// This is opposed to the `Continue()` method, which only evaluates one line of
    /// output at a time.
    /// - Returns: The resulting text evaluated by the ink engine, concatenated together.
    public func ContinueMaximally() -> String {
        IfAsyncWeCant("ContinueMaximally")
        
        var sb = ""
        while canContinue {
            sb += Continue()
        }
        
        return sb
    }
    
    public func ContentAtPath(_ path: Path) -> SearchResult? {
        return _mainContentContainer?.ContentAtPath(path)
    }
    
    public func KnotContainerWIthName(_ name: String) -> Container? {
        if let namedContainer = _mainContentContainer?.namedContent[name] {
            return namedContainer as? Container
        }
        return nil
    }
    
    public func PointerAtPath(_ path: Path) -> Pointer {
        if path.length == 0 {
            return Pointer.Null
        }
        
        // I think??? the original code seemed to use a constructor that didn't exist????
        // so just gonna assume we use default values here
        var p = Pointer(nil, 0)
        
        var pathLengthToUse = path.length
        
        var result: SearchResult?
        if path.lastComponent?.isIndex ?? false {
            pathLengthToUse = path.length - 1
            result = _mainContentContainer?.ContentAtPath(path, partialPathLength: pathLengthToUse)
            p.container = result?.container
            p.index = path.lastComponent!.index
        }
        else {
            result = _mainContentContainer?.ContentAtPath(path)
            p.container = result?.container
            p.index = -1
        }
        
        if result?.obj == nil || result?.obj == _mainContentContainer && pathLengthToUse > 0 {
            Error("Failed to find content at path '\(path)', and no approximation of it was possible.")
        }
        else if result?.approximate ?? false {
            Warning("Failed to find content at path '\(path)', so it was approximated to '\(result.obj.path)'")
        }
        
        return p
    }
    
    // Maximum snapshot stack:
    // - stateSnapshotDuringSave -- not retained, but returned to game code
    // - _stateSnapshotAtLastNewline (has older patch)
    // - _state (current, being patched)
    func StateSnapshot() {
        _stateSnapshotAtLastNewline = _state
        _state = _state.CopyAndStartPatching()
    }
    
    func RestoreStateSnapshot() {
        // Patched state had temporarily hijacked our
        // VariablesState and set its own callstack on it,
        // so we need to restore that.
        // If we're in the middle of saving, we may also
        // need to give the VariablesState the old patch.
        _stateSnapshotAtLastNewline?.RestoreAfterPatch()
        
        _state = _stateSnapshotAtLastNewline!
        _stateSnapshotAtLastNewline = nil
        
        // If save completed while the above snapshot was
        // active, we need to apply any changes made since
        // the save was started but before the snapshot was made.
        if !_asyncSaving {
            _state.ApplyAnyPatch()
        }
    }
    
    func DiscardSnapshot() {
        // Normally we want to integrate the patch
        // into the main global/counts dictionaries.
        // However, if we're in the middle of async
        // saving, we simply stay in a "patching" state,
        // albeit with the newer cloned patch.
        if !_asyncSaving {
            _state.ApplyAnyPatch()
        }
        
        // No longer need the snapshot.
        _stateSnapshotAtLastNewline = nil
    }
    
    /// Advanced usage!
    /// If you have a large story, and saving state to JSON takes too long for your
    /// framerate, you can temporarily freeze a copy of the state for saving on
    /// a separate thread. Internally, the engine maintains a "diff patch".
    /// When you're finished saving your state, call `BackgroundSaveComplete()`
    /// and that diff patch will be applied, allowing the story to continue
    /// in its usual mode.
    /// - Returns: The state for background thread save.
    public func CopyStateForBackgroundThreadSave() throws -> StoryState {
        IfAsyncWeCant("start saving on a background thread")
        if _asyncSaving {
            throw StoryError.cantSaveOnBackgroundThreadTwice
        }
        var stateToSave = _state
        _state = _state.CopyAndStartPatching()
        _asyncSaving = true
        return stateToSave
    }
    
    /// Releases the "frozen" save state started by `CopyStateForBackgroundThreadSave()`,
    /// applying its patch that it was using internally.
    public func BackgroundSaveComplete() {
        // CopyStateForBackgroundThreadSave() must be called outside
        // of any async ink evaluation, since otherwise you'd be saving
        // during an intermediate state.
        // However, it's possible to *complete* the save in the middle of
        // a glue-lookahead when there's a state stored in _stateSnapshotAtLastNewline.
        // This state will have its own patch that is newer than the save patch.
        // We hold off on the final apply until the glue-lookahead is finished.
        // In that case, the apply is always done, it's just that it may
        // apply the looked-ahead changes OR it may simply apply the changes
        // made during the save process to the old _stateSnapshotAtLastNewline state.
        if _stateSnapshotAtLastNewline == nil {
            _state.ApplyAnyPatch()
        }
        _asyncSaving = false
    }
    
    func Step() {
        var shouldAddToStream = true
        
        // Get current content
        var pointer = state.currentPointer
        if pointer.isNull {
            return
        }
        
        // Step directly to the first element of content in a container (if necessary)
        var containerToEnter = pointer.Resolve() as? Container
        while containerToEnter != nil {
            // Mark container as being entered
            VisitContainer(containerToEnter, atStart: true)
            
            // No content? the most we can do is step past it
            if containerToEnter?.content.count == 0 {
                break
            }
            
            pointer.Pointer.StartOf(containerToEnter!)
            containerToEnter = pointer.Resolve() as? Container
        }
        state.currentPointer = pointer
        
        _profiler?.Step(state.callStack)
        
        // Is the current content object:
        // - Normal content
        // - Or a logic/flow statement - if so, do it
        // Stop flow if we hit a stack pop when we're unable to pop (e.g. return/done statement in knot
        // that was diverted to rather than called as a function)
        var currentContentObj = pointer.Resolve()
        var isLogicOrFlowControl = PerformLogicAndFlowControl(currentContentObj)
        
        // Has flow been forced to end by flow control above?
        if state.currentPointer.isNull {
            return
        }
        
        if isLogicOrFlowControl {
            shouldAddToStream = false
        }
        
        // Choice with condition
        if let choicePoint = currentContentObj as? ChoicePoint {
            if let choice = ProcessChoice(choicePoint) {
                state.generatedChoices.append(choice)
            }
            
            currentContentObj = nil
            shouldAddToStream = false
        }
        
        // If the container has no content, then it will be
        // the "content" itself, but we skip over it.
        if currentContentObj is Container {
            shouldAddToStream = false
        }
        
        // Content to add to evaluation stack or the output stream
        if shouldAddToStream {
            // If we're pushing a variable pointer onto the evaluation stack, ensure that it's specific
            // to our current (possibly temporary) context index. And make a copy of the pointer
            // so that we're not editing the original runtime object.
            if let varPointer = currentContentObj as? VariablePointerValue, varPointer.contextIndex == -1 {
                // Create new object so we're not overwriting the story's own data
                var contextIdx = state.callStack.ContextForVariableNamed(varPointer.variableName)
                currentContentObj = VariablePointerValue(varPointer.variableName, contextIdx)
            }
            
            // Expression evaluation content
            if state.inExpressionEvaluation {
                state.PushEvaluationStack(currentContentObj)
            }
            
            // Output stream content (i.e. not expression evaluation)
            else {
                state.PushToOutputStream(currentContentObj)
            }
        }
        
        // Increment the content pointer, following diverts if necessary
        NextContent()
        
        // Starting a thread should be done after the increment to thecontent pointer,
        // so that when returning from the thread, it returns to the content after this instruction.
        if let controlCmd = currentContentObj as? ControlCommand, controlCmd.commandType == .startThread {
            state.callStack.PushThread()
        }
    }
    
    /// Mark a container as having been visited
    func VisitContainer(_ container: Container, _ atStart: Bool) {
        if !container.countingAtStartOnly || atStart {
            if container.visitsShouldBeCounted {
                state.IncrementVisitCountForContainer(container)
            }
            
            if container.turnIndexShouldBeCounted {
                state.RecordTurnIndexVisitToContainer(container)
            }
        }
    }
    
    var _prevContainers: [Container] = []
    
    // TODO: VisitChangedContainersDueToDivert() and onwards!
    
    
    private var _mainContentContainer: Container?
    private var _listDefinitions: ListDefinitionsOrigin?
    
    struct ExternalFunctionDef {
        var function: ExternalFunction
        var lookaheadSafe: Bool
    }
    
    private var _externals: [String: ExternalFunctionDef]
    private var _variableObservers: [String: VariableObserver]
    private var _hasValidatedExternals: Bool
    
    private var _temporaryEvaluationContainer: Container?
    
    private var _state: StoryState
    
    private var _asyncContinueActive: Bool
    private var _stateSnapshotAtLastNewline: StoryState? = nil
    private var _sawLookaheadUnsafeFunctionAfterNewline: Bool = false
    
    private var _recursiveContinueCount: Int = 0
    
    private var _asyncSaving: Bool = false
    
    private var _profiler: Profiler?
}

