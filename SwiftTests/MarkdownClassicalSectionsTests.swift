import Foundation
import Testing
@testable import TransitStudio

/// Direct tests for the classical markdown section builders that previously
/// had no coverage: MarkdownClassicalAuditExportBuilder,
/// MarkdownClassicalDirectionExportBuilder and MarkdownFormatting helpers.
struct MarkdownClassicalSectionsTests {

    // MARK: - MarkdownFormatting helpers

    @Test func warningsHelperOmitsSectionWhenEmpty() {
        #expect(MarkdownExportBuilder.warnings([]).isEmpty)
    }

    @Test func warningsHelperRendersBulletedSection() {
        let lines = MarkdownExportBuilder.warnings(["时间精度不足", "宫制回退"])
        #expect(lines == ["", "## 警告", "", "- 时间精度不足", "- 宫制回退"])
    }

    @Test func degreeHelperFormatsFixedDigits() {
        #expect(MarkdownExportBuilder.degree(12.3456, digits: 2) == "12.35°")
        #expect(MarkdownExportBuilder.degree(0, digits: 4) == "0.0000°")
        #expect(MarkdownExportBuilder.degree(-1.5, digits: 1) == "-1.5°")
    }

    @Test func sectionErrorBlockOmitsSectionWhenEmpty() {
        #expect(MarkdownExportBuilder.sectionErrorBlock(nil).isEmpty)
        #expect(MarkdownExportBuilder.sectionErrorBlock([:]).isEmpty)
    }

    @Test func sectionErrorBlockMapsKnownKeysToChineseLabels() {
        let lines = MarkdownExportBuilder.sectionErrorBlock([
            "primary_directions": "swe failure",
            "hyleg_alcocoden": "no candidate",
        ])
        let text = lines.joined(separator: "\n")
        #expect(text.contains("## 子模块错误"))
        #expect(text.contains("**主限法**: swe failure"))
        #expect(text.contains("**Hyleg/Alcocoden**: no candidate"))
    }

    // MARK: - MarkdownClassicalAuditExportBuilder

    @Test func almutenSectionRendersWinnerAndScoreTable() throws {
        let almuten = try decode(AlmutenFiguris.self, json: """
        {
          "winner": "JUPITER",
          "winner_id": "JUPITER",
          "score_table": [
            {
              "planet": "木星",
              "total": 25,
              "contributions": [
                {"point": "Domicile", "dignity": "庙", "weight": 5},
                {"point": "Triplicity", "dignity": "三分", "weight": 3}
              ]
            },
            {
              "planet": "金星",
              "total": 18,
              "contributions": [
                {"point": "Exaltation", "dignity": "旺", "weight": 4}
              ]
            }
          ],
          "points_used": ["Domicile", "Exaltation", "Triplicity"],
          "method": "almuten_score",
          "confidence": "medium"
        }
        """)
        let lines = MarkdownExportBuilder.almutenSection(almuten)
        let text = lines.joined(separator: "\n")

        #expect(text.contains("## Almuten Figuris（全盘最尊贵行星）"))
        #expect(text.contains("- 最尊贵行星：**JUPITER**"))
        #expect(text.contains("| 行星 | 总分 | 明细 |"))
        #expect(text.contains("| 木星 | 25 | Domicile(庙+5) Triplicity(三分+3) |"))
        #expect(text.contains("| 金星 | 18 | Exaltation(旺+4) |"))
    }

    @Test func almutenSectionHandlesMissingWinner() throws {
        let almuten = try decode(AlmutenFiguris.self, json: """
        {"winner": null, "winner_id": null, "score_table": null, "method": "almuten_score"}
        """)
        let text = MarkdownExportBuilder.almutenSection(almuten).joined(separator: "\n")
        #expect(text.contains("## Almuten Figuris（全盘最尊贵行星）"))
        #expect(!text.contains("- 最尊贵行星"))
    }

    @Test func hylegSectionRendersSelectionCandidatesAndAlcocoden() throws {
        let hyleg = try decode(HylegAlcocoden.self, json: """
        {
          "hyleg": {
            "selected": "SUN",
            "selected_id": "SUN",
            "reason": "白天出生，太阳位于始宫",
            "candidates": [
              {"name": "太阳", "eligible": true, "reason": "昼盘太阳在始宫", "house": 1},
              {"name": "月亮", "eligible": false, "reason": "夜盘优先", "house": 5}
            ]
          },
          "alcocoden": {
            "selected": "JUPITER",
            "selected_id": "JUPITER",
            "dignity": "庙",
            "candidates": [
              {
                "planet": "JUPITER",
                "planet_id": "JUPITER",
                "dignity_at_hyleg": "Domicile",
                "weight": 7,
                "sees_hyleg": true,
                "own_condition_score": 5,
                "own_condition_summary": "顺行入庙",
                "reason": "入庙且见 Hyleg"
              }
            ]
          },
          "warning": "无合格候选时输出会为空"
        }
        """)
        let text = MarkdownExportBuilder.hylegSection(hyleg).joined(separator: "\n")

        #expect(text.contains("## Hyleg / Alcocoden（生命主星）"))
        #expect(text.contains("- **Hyleg**：SUN"))
        #expect(text.contains("- 理由：白天出生，太阳位于始宫"))
        #expect(text.contains("| Hyleg 候选 | 宫位 | 状态 | 理由 |"))
        #expect(text.contains("| 太阳 | 1 | selected/eligible | 昼盘太阳在始宫 |"))
        #expect(text.contains("| 月亮 | 5 | rejected | 夜盘优先 |"))
        #expect(text.contains("- **Alcocoden**：JUPITER"))
        #expect(text.contains("- 尊贵：庙"))
        #expect(text.contains("| JUPITER | Domicile | 7 | yes | 顺行入庙 | 入庙且见 Hyleg |"))
        #expect(text.contains("- 备注：无合格候选时输出会为空"))
    }

    @Test func hylegSectionHandlesNoCandidates() throws {
        let hyleg = try decode(HylegAlcocoden.self, json: """
        {"hyleg": {"selected": null, "reason": null}, "alcocoden": null}
        """)
        let text = MarkdownExportBuilder.hylegSection(hyleg).joined(separator: "\n")
        #expect(text.contains("- Hyleg：无合格候选"))
    }

    @Test func prenatalSyzygySectionRendersFullMoonWithBothLuminaries() throws {
        let syzygy = try decode(PrenatalSyzygy.self, json: """
        {
          "syzygy_type": "full_moon",
          "exact_utc": "1989-12-12T17:33:00Z",
          "longitude": 270.0,
          "sun_position": 270.0,
          "moon_position": 270.0,
          "sign": "摩羯",
          "degree": 0.0,
          "ruler": "土星",
          "ruler_id": "SATURN",
          "syzygy_degree_used": "sun",
          "method": "swiss_ephemeris"
        }
        """)
        let text = MarkdownExportBuilder.prenatalSyzygySection(syzygy).joined(separator: "\n")

        #expect(text.contains("## 产前朔望（Prenatal Syzygy）"))
        #expect(text.contains("- 类型：望月（Full Moon）"))
        #expect(text.contains("- 精确 UTC：1989-12-12T17:33:00Z"))
        #expect(text.contains("- 日月黄经：Sun 270.0000° / Moon 270.0000°"))
        #expect(text.contains("- 位置：摩羯 0.0°"))
        #expect(text.contains("- syzygy_degree_used：sun"))
        #expect(text.contains("- 主星：土星"))
    }

    @Test func prenatalSyzygySectionRendersNewMoonType() throws {
        let syzygy = try decode(PrenatalSyzygy.self, json: """
        {"syzygy_type": "new_moon", "exact_utc": "1990-01-01T00:00:00Z", "sign": "摩羯", "degree": 10.5}
        """)
        let text = MarkdownExportBuilder.prenatalSyzygySection(syzygy).joined(separator: "\n")
        #expect(text.contains("- 类型：朔月（New Moon）"))
    }

    // MARK: - MarkdownClassicalDirectionExportBuilder

    @Test func primaryDirectionSectionSplitsDirectAndConverseTables() throws {
        let rows = [
            try decode(PrimaryDirection.self, json: """
            {
              "id": "pd-1", "promissor": "太阳", "promissor_id": "SUN",
              "significator": "上升点", "significator_id": "ASC",
              "aspect_type": "conjunction", "aspect_name": "合相",
              "natal_promissor_lon": 10.0, "natal_significator_lon": 280.0,
              "direction_type": "direct", "arc_signed": 1.5, "arc_abs": 1.5,
              "age_from_abs_arc": 1.6, "event_date_after_birth": "1991-08-01"
            }
            """),
            try decode(PrimaryDirection.self, json: """
            {
              "id": "pd-2", "promissor": "月亮", "promissor_id": "MOON",
              "significator": "天顶", "significator_id": "MC",
              "aspect_type": "square", "aspect_name": "刑相",
              "natal_promissor_lon": 30.0, "natal_significator_lon": 200.0,
              "direction_type": "converse", "arc_signed": -2.25, "arc_abs": 2.25,
              "age_from_abs_arc": 2.4, "symbolic_date_from_signed_arc": "1988-06-15"
            }
            """),
        ]
        let text = MarkdownExportBuilder.primaryDirectionSection(rows).joined(separator: "\n")

        #expect(text.contains("### Primary Directions"))
        #expect(text.contains("#### 1 条逆推方向"))
        #expect(text.contains("#### 1 条顺推方向"))
        #expect(text.contains("| 太阳 | 上升点 | 合相 | +1.50° | 1.6 | 1991-08-01 | 顺推 |"))
        #expect(text.contains("| 月亮 | 天顶 | 刑相 | -2.25° | 2.4 | 1988-06-15 | 出生前符号日 |"))
    }

    @Test func primaryDirectionSectionReturnsEmptyForNoRows() {
        #expect(MarkdownExportBuilder.primaryDirectionSection([]).isEmpty)
    }

    @Test func circumambulationSectionRendersSystemAndBoundaryTable() throws {
        let circ = try decode(Circumambulation.self, json: """
        {
          "id": "circ-1", "system": "primary_direction",
          "start_lon": 10.0, "current_ruler": "火星", "current_ruler_id": "MARS",
          "current_bound_info": "白羊 0°-6° 火星界",
          "current_directed_position": 15.5,
          "naibod_rate": 1.0146,
          "boundaries": [
            {
              "sign": "白羊", "start_degree": 0.0, "end_degree": 6.0,
              "ruler": "火星", "ruler_id": "MARS", "arc_value": 1.2,
              "age_at_boundary": 1.2, "estimated_date": "1991-04-01", "is_current": true
            },
            {
              "sign": "白羊", "start_degree": 6.0, "end_degree": 14.0,
              "ruler": "金星", "ruler_id": "VENUS", "arc_value": 3.0,
              "age_at_boundary": 3.0, "estimated_date": "1993-01-15", "is_current": false
            }
          ]
        }
        """)
        let text = MarkdownExportBuilder.circumambulationSection([circ]).joined(separator: "\n")

        #expect(text.contains("## Circumambulations through the Bounds（沿界推进）"))
        #expect(text.contains("- 系统：primary_direction"))
        #expect(text.contains("- Naibod rate：1.0146°/年"))
        #expect(text.contains("- 当前界主：火星"))
        #expect(text.contains("| 白羊 | 6° | 火星 | 1.20° | 1.2 | 1991-04-01 |"))
        #expect(text.contains("| 白羊 | 14° | 金星 | 3.00° | 3.0 | 1993-01-15 |"))
    }

    @Test func circumambulationSectionReturnsHeaderOnlyForNoRows() {
        let lines = MarkdownExportBuilder.circumambulationSection([])
        #expect(lines.joined(separator: "\n").contains("## Circumambulations through the Bounds（沿界推进）"))
    }

    // MARK: - Helpers

    private func decode<T: Decodable>(_ type: T.Type, json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
}
