import { screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { getDefaultFilterProps } from "#/components/Filter/storyHelpers";
import { MockTemplate } from "#/testHelpers/entities";
import { renderWithAuth } from "#/testHelpers/renderHelpers";
import type { TemplateFilterState } from "./TemplatesFilter";
import { TemplatesPageView } from "./TemplatesPageView";

const templates = [
	{
		...MockTemplate,
		id: "b",
		display_name: "Middle",
		updated_at: "2024-02-01T00:00:00Z",
	},
	{
		...MockTemplate,
		id: "a",
		display_name: "Oldest",
		updated_at: "2024-01-01T00:00:00Z",
	},
	{
		...MockTemplate,
		id: "c",
		display_name: "Newest",
		updated_at: "2024-03-01T00:00:00Z",
	},
];

const rowOrder = () =>
	screen
		.getAllByText(/^(Oldest|Middle|Newest)$/)
		.map((name) => name.textContent);

describe("TemplatesPageView", () => {
	it("sorts by Last updated: newest first, then oldest first, then server order", async () => {
		const user = userEvent.setup();
		renderWithAuth(
			<TemplatesPageView
				filterState={getDefaultFilterProps<TemplateFilterState>({
					menus: {},
					values: {},
				})}
				showOrganizations={false}
				canCreateTemplates={false}
				templateBuilderEnabled={false}
				examples={[]}
				templates={templates}
				templateUpdatePermissions={{}}
				workspacePermissions={{}}
			/>,
		);
		const header = await screen.findByRole("button", { name: "Last updated" });

		expect(rowOrder()).toEqual(["Middle", "Oldest", "Newest"]);
		await user.click(header);
		expect(rowOrder()).toEqual(["Newest", "Middle", "Oldest"]);
		await user.click(header);
		expect(rowOrder()).toEqual(["Oldest", "Middle", "Newest"]);
		await user.click(header);
		expect(rowOrder()).toEqual(["Middle", "Oldest", "Newest"]);
	});
});
