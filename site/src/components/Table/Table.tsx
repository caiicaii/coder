/**
 * Copied from shadc/ui on 02/03/2025
 * @see {@link https://ui.shadcn.com/docs/components/table}
 */
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "cn";
import {
	ChevronDownIcon,
	ChevronsUpDownIcon,
	ChevronUpIcon,
} from "lucide-react";

type TableProps = React.ComponentProps<"table"> & {
	wrapperClassName?: string;
};

export const Table: React.FC<TableProps> = ({
	className,
	wrapperClassName,
	...props
}) => {
	return (
		<div className={cn("relative w-full overflow-auto", wrapperClassName)}>
			<table
				className={cn(
					"w-full caption-bottom text-xs font-medium text-content-secondary border-separate border-spacing-0",
					className,
				)}
				{...props}
			/>
		</div>
	);
};

export const TableHeader: React.FC<React.ComponentProps<"thead">> = ({
	className,
	...props
}) => {
	return <thead className={cn("[&_td]:border-none", className)} {...props} />;
};

const tableBodyVariants = cva(null, {
	variants: {
		size: {
			lg: "[&>tr>*]:box-border [&>tr>*]:h-[72px]",
		},
	},
});

type TableBodyProps = React.ComponentProps<"tbody"> &
	VariantProps<typeof tableBodyVariants>;

export const TableBody: React.FC<TableBodyProps> = ({
	className,
	size,
	...props
}) => {
	return (
		<tbody
			className={cn(
				// Select the outline by child position: a body row can start with a
				// scope="row" th, and td:first-of-type would skip it and treat the
				// second cell as the first.
				"[&>tr:first-of-type>*]:border-t [&>tr>*:first-child]:border-l",
				"[&>tr:last-child>*]:border-b [&>tr>*:last-child]:border-r",
				"[&>tr:first-of-type>*:first-child]:rounded-tl-md [&>tr:first-of-type>*:last-child]:rounded-tr-md",
				"[&>tr:last-child>*:first-child]:rounded-bl-md [&>tr:last-child>*:last-child]:rounded-br-md",
				tableBodyVariants({ size }),
				className,
			)}
			{...props}
		/>
	);
};

const tableRowVariants = cva(
	[
		"border-0 border-b border-solid border-border transition-colors",
		"data-[state=selected]:bg-surface-secondary",
	],
	{
		variants: {
			hover: {
				false: null,
				true: cn(
					"cursor-pointer outline-none hover:outline-solid hover:outline-1 focus-visible:outline-solid focus-visible:outline-1 -outline-offset-1 outline-border-secondary",
					"first:rounded-t-md last:rounded-b-md",
				),
			},
		},
		defaultVariants: {
			hover: false,
		},
	},
);

export type TableRowProps = React.ComponentProps<"tr"> &
	VariantProps<typeof tableRowVariants>;

export const TableRow: React.FC<TableRowProps> = ({
	className,
	hover,
	...props
}) => {
	return (
		<tr
			className={cn(
				tableRowVariants({ hover }),
				"data-[state=selected]:bg-surface-secondary",
				className,
			)}
			{...props}
		/>
	);
};

export const TableHead: React.FC<React.ComponentProps<"th">> = ({
	className,
	scope = "col",
	...props
}) => {
	return (
		<th
			className={cn(
				"p-3 text-left align-middle font-semibold",
				"has-[[role=checkbox]]:pr-0 *:[[role=checkbox]]:translate-y-[2px]",
				className,
			)}
			scope={scope}
			{...props}
		/>
	);
};

export type SortDirection = "asc" | "desc";

type SortableTableHeadProps = React.ComponentProps<"th"> & {
	/** Current sort direction for this column, or undefined when unsorted. */
	direction: SortDirection | undefined;
	/** Called with the next direction: descending, then ascending, then unsorted. */
	onSort: (direction: SortDirection | undefined) => void;
};

export const SortableTableHead: React.FC<SortableTableHeadProps> = ({
	direction,
	onSort,
	children,
	...props
}) => {
	const Icon =
		direction === "asc"
			? ChevronUpIcon
			: direction === "desc"
				? ChevronDownIcon
				: ChevronsUpDownIcon;
	return (
		<TableHead
			aria-sort={
				direction === "asc"
					? "ascending"
					: direction === "desc"
						? "descending"
						: "none"
			}
			{...props}
		>
			<button
				type="button"
				onClick={() =>
					onSort(
						direction === undefined
							? "desc"
							: direction === "desc"
								? "asc"
								: undefined,
					)
				}
				className="inline-flex items-center gap-1 rounded-sm border-0 bg-transparent p-0 font-semibold text-inherit cursor-pointer hover:text-content-primary focus-visible:outline focus-visible:outline-2 focus-visible:outline-content-link"
			>
				{children}
				<Icon
					aria-hidden="true"
					className={cn("size-icon-xs", !direction && "text-content-secondary")}
				/>
			</button>
		</TableHead>
	);
};

export const TableCell: React.FC<React.ComponentProps<"td">> = ({
	className,
	...props
}) => {
	return (
		<td
			{...props}
			className={cn(
				"border-0 border-t border-border border-solid",
				"p-3 align-middle has-[[role=checkbox]]:pr-0 *:[[role=checkbox]]:translate-y-[2px]",
				className,
			)}
		/>
	);
};
