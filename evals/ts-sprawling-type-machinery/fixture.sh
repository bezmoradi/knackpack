#!/bin/bash
# A procurement app's vendor list, plus an uncommitted three-field vendor form
# built on a new generic form builder, field class hierarchy and mapped types.
set -euo pipefail
git init -q -b main
git config user.name "Hannah Lindqvist"
git config user.email "hannah.lindqvist@example.com"
mkdir -p src
cat > package.json <<'JSON'
{
  "name": "procurement-portal",
  "version": "1.8.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc --noEmit && vite build",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "typescript": "^5.9.3",
    "vite": "^7.1.5"
  }
}
JSON
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "isolatedModules": true,
    "noEmit": true,
    "strict": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
JSON
cat > .gitignore <<'TXT'
node_modules/
dist/
TXT
cat > src/vendors.ts <<'TS'
export interface Vendor {
  id: string;
  companyName: string;
  contactEmail: string;
  paymentTermsDays: number;
}

export type NewVendor = Omit<Vendor, "id">;

export async function listVendors(): Promise<Vendor[]> {
  const res = await fetch("/api/vendors");
  if (!res.ok) throw new Error(`Loading vendors failed: ${res.status}`);
  return (await res.json()) as Vendor[];
}

export async function createVendor(vendor: NewVendor): Promise<void> {
  const res = await fetch("/api/vendors", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(vendor),
  });
  if (!res.ok) throw new Error(`Saving the vendor failed: ${res.status}`);
}
TS
cat > src/main.ts <<'TS'
import { listVendors } from "./vendors";

const list = document.querySelector<HTMLUListElement>("#vendors")!;

async function renderVendors(): Promise<void> {
  const vendors = await listVendors();
  list.replaceChildren(
    ...vendors.map((vendor) => {
      const item = document.createElement("li");
      item.textContent = `${vendor.companyName} (net ${vendor.paymentTermsDays})`;
      return item;
    }),
  );
}

void renderVendors();
TS
git add -A
git commit -q -m "Vendor list page"

# Uncommitted: the add-vendor form.
mkdir -p src/forms
cat > src/forms/types.ts <<'TS'
export type FieldResult<TValue> = { ok: true; value: TValue } | { ok: false; message: string };

export interface FieldDef<TValue, TRequired extends boolean = boolean> {
  readonly label: string;
  readonly isRequired: TRequired;
  parse(raw: string | null): FieldResult<TValue | undefined>;
}

export type ValueOf<TField> = TField extends FieldDef<infer TValue, boolean> ? TValue : never;

export type RequiredKeys<TSchema> = {
  [K in keyof TSchema]: TSchema[K] extends FieldDef<any, true> ? K : never;
}[keyof TSchema];

export type OptionalKeys<TSchema> = Exclude<keyof TSchema, RequiredKeys<TSchema>>;

type Flatten<T> = { [K in keyof T]: T[K] } & {};

export type InferValues<TSchema extends Record<string, FieldDef<any>>> = Flatten<
  { [K in RequiredKeys<TSchema>]: ValueOf<TSchema[K]> } & {
    [K in OptionalKeys<TSchema>]?: ValueOf<TSchema[K]>;
  }
>;

export type FieldErrors<TSchema extends Record<string, FieldDef<any>>> = {
  [K in keyof TSchema]?: string;
};

export type FormResult<TSchema extends Record<string, FieldDef<any>>> =
  | { ok: true; values: InferValues<TSchema> }
  | { ok: false; errors: FieldErrors<TSchema> };
TS
cat > src/forms/fields.ts <<'TS'
import type { FieldDef, FieldResult } from "./types";

export abstract class BaseField<TValue, TRequired extends boolean> implements FieldDef<TValue, TRequired> {
  constructor(
    readonly label: string,
    readonly isRequired: TRequired,
  ) {}

  parse(raw: string | null): FieldResult<TValue | undefined> {
    const text = raw?.trim() ?? "";
    if (text === "") {
      return this.isRequired ? { ok: false, message: `${this.label} is required` } : { ok: true, value: undefined };
    }
    return this.parseText(text);
  }

  protected abstract parseText(text: string): FieldResult<TValue>;
}

export class TextField<TRequired extends boolean = false> extends BaseField<string, TRequired> {
  private constructor(
    label: string,
    isRequired: TRequired,
    private readonly maxLength: number,
    private readonly pattern?: { regex: RegExp; message: string },
  ) {
    super(label, isRequired);
  }

  static create(label: string): TextField<false> {
    return new TextField(label, false, 200);
  }

  required(): TextField<true> {
    return new TextField(this.label, true, this.maxLength, this.pattern);
  }

  max(maxLength: number): TextField<TRequired> {
    return new TextField(this.label, this.isRequired, maxLength, this.pattern);
  }

  matching(regex: RegExp, message: string): TextField<TRequired> {
    return new TextField(this.label, this.isRequired, this.maxLength, { regex, message });
  }

  protected parseText(text: string): FieldResult<string> {
    if (text.length > this.maxLength) {
      return { ok: false, message: `${this.label} must be at most ${this.maxLength} characters` };
    }
    if (this.pattern && !this.pattern.regex.test(text)) {
      return { ok: false, message: this.pattern.message };
    }
    return { ok: true, value: text };
  }
}

export class NumberField<TRequired extends boolean = false> extends BaseField<number, TRequired> {
  private constructor(
    label: string,
    isRequired: TRequired,
    private readonly bounds: { min: number; max: number; integer: boolean },
  ) {
    super(label, isRequired);
  }

  static create(label: string): NumberField<false> {
    return new NumberField(label, false, { min: -Infinity, max: Infinity, integer: false });
  }

  required(): NumberField<true> {
    return new NumberField(this.label, true, this.bounds);
  }

  integer(): NumberField<TRequired> {
    return new NumberField(this.label, this.isRequired, { ...this.bounds, integer: true });
  }

  between(min: number, max: number): NumberField<TRequired> {
    return new NumberField(this.label, this.isRequired, { ...this.bounds, min, max });
  }

  protected parseText(text: string): FieldResult<number> {
    const value = Number(text);
    if (!Number.isFinite(value)) return { ok: false, message: `${this.label} must be a number` };
    if (this.bounds.integer && !Number.isInteger(value)) {
      return { ok: false, message: `${this.label} must be a whole number` };
    }
    if (value < this.bounds.min || value > this.bounds.max) {
      return { ok: false, message: `${this.label} must be between ${this.bounds.min} and ${this.bounds.max}` };
    }
    return { ok: true, value };
  }
}
TS
cat > src/forms/form-builder.ts <<'TS'
import type { FieldDef, FieldErrors, FormResult, InferValues } from "./types";

export type FieldReader = (name: string) => string | null;

export class FormParser<TSchema extends Record<string, FieldDef<any>>> {
  constructor(private readonly schema: TSchema) {}

  parse(read: FieldReader): FormResult<TSchema> {
    const values: Record<string, unknown> = {};
    const errors: FieldErrors<TSchema> = {};
    let valid = true;
    for (const name of Object.keys(this.schema) as Array<keyof TSchema & string>) {
      const result = this.schema[name].parse(read(name));
      if (result.ok) {
        if (result.value !== undefined) values[name] = result.value;
      } else {
        errors[name] = result.message;
        valid = false;
      }
    }
    return valid ? { ok: true, values: values as InferValues<TSchema> } : { ok: false, errors };
  }
}

export class FormBuilder<TSchema extends Record<string, FieldDef<any>>> {
  private constructor(private readonly schema: TSchema) {}

  static create(): FormBuilder<{}> {
    return new FormBuilder({});
  }

  field<TName extends string, TField extends FieldDef<any>>(
    name: TName,
    field: TField,
  ): FormBuilder<TSchema & Record<TName, TField>> {
    return new FormBuilder({ ...this.schema, [name]: field } as TSchema & Record<TName, TField>);
  }

  build(): FormParser<TSchema> {
    return new FormParser(this.schema);
  }
}
TS
cat > src/vendor-form.ts <<'TS'
import { NumberField, TextField } from "./forms/fields";
import { FormBuilder, type FieldReader, type FormParser } from "./forms/form-builder";
import type { FieldErrors } from "./forms/types";
import type { NewVendor } from "./vendors";

const vendorSchema = FormBuilder.create()
  .field("companyName", TextField.create("Company name").required().max(120))
  .field(
    "contactEmail",
    TextField.create("Contact email").required().matching(/^[^@\s]+@[^@\s]+\.[^@\s]+$/, "Enter an email address"),
  )
  .field("paymentTermsDays", NumberField.create("Payment terms (days)").integer().between(0, 120))
  .build();

export type VendorFormErrors = FieldErrors<typeof vendorSchema extends FormParser<infer TSchema> ? TSchema : never>;

export function readVendorForm(read: FieldReader): { ok: true; vendor: NewVendor } | { ok: false; errors: VendorFormErrors } {
  const result = vendorSchema.parse(read);
  if (!result.ok) return { ok: false, errors: result.errors };
  const { companyName, contactEmail, paymentTermsDays = 30 } = result.values;
  return { ok: true, vendor: { companyName, contactEmail, paymentTermsDays } };
}
TS
cat > src/main.ts <<'TS'
import { readVendorForm } from "./vendor-form";
import { createVendor, listVendors } from "./vendors";

const list = document.querySelector<HTMLUListElement>("#vendors")!;
const form = document.querySelector<HTMLFormElement>("#new-vendor")!;

async function renderVendors(): Promise<void> {
  const vendors = await listVendors();
  list.replaceChildren(
    ...vendors.map((vendor) => {
      const item = document.createElement("li");
      item.textContent = `${vendor.companyName} (net ${vendor.paymentTermsDays})`;
      return item;
    }),
  );
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const data = new FormData(form);
  const result = readVendorForm((name) => {
    const value = data.get(name);
    return typeof value === "string" ? value : null;
  });
  for (const output of form.querySelectorAll<HTMLOutputElement>("output[data-for]")) {
    output.textContent = result.ok ? "" : (result.errors[output.dataset.for as keyof typeof result.errors] ?? "");
  }
  if (!result.ok) return;
  const status = form.querySelector<HTMLOutputElement>("output[name=status]")!;
  try {
    await createVendor(result.vendor);
    form.reset();
    status.textContent = "Vendor added";
    await renderVendors();
  } catch (error) {
    status.textContent = error instanceof Error ? error.message : "Saving the vendor failed";
  }
});

void renderVendors();
TS
