import XCTest
@testable import SwiftInk

final class SwiftInkTests: XCTestCase {
    func testB001() throws {
        try loadStoryAndTest(named: "B001")
    }
    
    func testB002() throws {
        try loadStoryAndTest(named: "B002")
    }
    
    func testB003() throws {
        try loadStoryAndTest(named: "B003")
    }
    
    func testB004() throws {
        try loadStoryAndTest(named: "B004")
    }
    
    func testB005() throws {
        try loadStoryAndTest(named: "B005", withChoices: [0])
    }
    
    func testB006() throws {
        try loadStoryAndTest(named: "B006")
    }
    
    func testB007() throws {
        try loadStoryAndTest(named: "B007")
    }
    
    func testFogg() throws {
        try loadStoryAndTest(named: "fogg", withChoices: [0, 1])
    }

    func testKnots() throws {
        try loadStoryAndTest(named: "knot_test", withChoices: [0, 0, 1])
    }
    
    func loadStoryAndRun(named storyName: String, withChoices choices: [Int] = []) throws -> String {
        guard let fp = Bundle.module.path(forResource: "TestData/\(storyName)/\(storyName)", ofType: "json") else {
            fatalError("ouch")
        }
        
        let url = URL(fileURLWithPath: fp)
        let jsonString = try String(contentsOf: url)
        let s = try Story(jsonString)
        
        var output = ""
        var choiceNum = 0
        
        while true {
            output += try s.continueMaximally()
            if !s.currentChoices.isEmpty {
                try s.chooseChoice(atIndex: choices[choiceNum])
                choiceNum += 1
            }
            else {
                return output
            }
        }
    }
    
    func loadStoryAndTest(named storyName: String, withChoices choices: [Int] = []) throws {
        let output = try loadStoryAndRun(named: storyName, withChoices: choices)
        
        guard let expectedOutputFilepath = Bundle.module.path(forResource: "TestData/\(storyName)/\(storyName)-output", ofType: "txt") else {
            fatalError("ouch")
        }
        
        let url = URL(fileURLWithPath: expectedOutputFilepath)
        let expectedOutput = try String(contentsOf: url)
        
        print("TEST FOR \"\(storyName)\"")
        print("EXPECTED:")
        print(expectedOutput)
        print("==========")
        print("RECEIVED:")
        print(output)
        print("==========")
        XCTAssert(output == expectedOutput)
    }

    func testExternalFunctions() throws {
        // Load the story
        guard let fp = Bundle.module.path(forResource: "TestData/external_functions/ExternalFunctions", ofType: "json") else {
            fatalError("Cannot find the story file")
        }
        let url = URL(fileURLWithPath: fp)
        let jsonString = try String(contentsOf: url)
        let story = try Story(jsonString)
        
        // Prepare to track the external function calls
        var calledFunctions: [String] = []
        
        
        // Bind the external functions to the story
        try story.bindExternalFunctionGeneral(named: "onSuccess", { args in
            NSLog("Invoked onSuccess Function with args: \(String(describing: args))")
            calledFunctions.append("onSuccess + \(String(describing: args))")
            return nil
        }, lookaheadSafe: true)
        try story.bindExternalFunctionGeneral(named: "onFailure") { args in
            NSLog("Invoked onFailure Function")
            calledFunctions.append("onFailure")
            return nil
        }
        try story.bindExternalFunctionGeneral(named: "onDialogueEnd") { args in
            NSLog("Invoked onDialogueEnd Function")
            calledFunctions.append("onDialogueEnd")
            return nil
        }
        
        // Run the story, making choices as needed
        var output = ""
        var choiceNum = 0
        let choices = [0, 0,1,0,1,1]
        
        while true {
            let res = try story.continueMaximally()
            output += res
            NSLog(res)
            if !story.currentChoices.isEmpty {
                NSLog("Picking choice number \(choices[choiceNum]) of \(story.currentChoices.count) possible choices")
                try story.chooseChoice(atIndex: choices[choiceNum])
                choiceNum += 1
            } else {
                NSLog("No more choices available")
                break
            }
        }
        
        // Expected sequence of external function calls
        let expectedFunctionCalls = ["onSuccess + [Optional(100)]", "onDialogueEnd"]
        
        // Verify that the external functions were called in the expected order
        XCTAssertEqual(calledFunctions, expectedFunctionCalls)
    }
}
