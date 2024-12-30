//
//  schemas.swift
//  Havital
//
//  Created by 吳柏宗 on 2024/12/28.
//

import GoogleGenerativeAI
let trainingPlanSchema = Schema(
    type: .object,
    description: "Training schedule for the week",
    properties: [
        "purpose": Schema(
            type: .string,
            description: "The purpose of the week's training",
            nullable: false
        ),
        "tips": Schema(
            type: .string,
            description: "Tips for the training",
            nullable: false
        ),
        "days": Schema(
            type: .array,
            description: "List of training days",
            items: Schema(
                type: .object,
                properties: [
                    "target": Schema(
                        type: .string,
                        description: "The target activity for the day",
                        nullable: false
                    ),
                    "tips": Schema(
                        type: .string,
                        description: "The tips for the day",
                        nullable: true
                    ),
                    "training_items": Schema(
                        type: .array,
                        description: "List of training items for the day",
                        items: Schema(
                            type: .object,
                            properties: [
                                "name": Schema(
                                    type: .string,
                                    description: "Name of the training item",
                                    nullable: false
                                ),
                                "duration_minutes": Schema(
                                    type: .integer,
                                    description: "Duration of the training in minutes",
                                    nullable: true
                                ),
                                "goals": Schema(
                                    type: .object,
                                    description: "Goals for the training item",
                                    nullable: true, properties: [
                                        "times": Schema(
                                            type: .integer,
                                            description: "Number of times to perform the activity",
                                            nullable: true
                                        ),
                                        "heart_rate": Schema(
                                            type: .integer,
                                            description: "Target heart rate during the activity",
                                            nullable: true
                                        ),
                                        "pace": Schema(
                                            type: .integer,
                                            description: "Minite:seconds/1 km",
                                            nullable: true
                                        )
                                    ]
                                )
                            ],
                            requiredProperties: ["name"]
                        )
                    )
                ],
                requiredProperties: ["target", "training_items"]
            )
        )
    ],
    requiredProperties: ["purpose", "tips", "days"]
)

let summarySchema = Schema(
    type: .object,
    description: "Weekly training summary and analysis",
    properties: [
        "further_suggestion": Schema(
            type: .string,
            description: "Suggestions for future training",
            nullable: false
        ),
        "summary": Schema(
            type: .string,
            description: "Overall summary of the week's training performance",
            nullable: false
        ),
        "training_analysis": Schema(
            type: .string,
            description: "Detailed analysis of individual training sessions",
            nullable: false
        )
    ],
    requiredProperties: ["further_suggestion", "summary", "training_analysis"]
)