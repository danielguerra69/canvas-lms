/*
 * Copyright (C) 2018 - present Instructure, Inc.
 *
 * This file is part of Canvas.
 *
 * Canvas is free software: you can redistribute it and/or modify it under
 * the terms of the GNU Affero General Public License as published by the Free
 * Software Foundation, version 3 of the License.
 *
 * Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
 * A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Affero General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

import React from 'react'
import {render} from 'react-testing-library'
import {mockAssignment, mockOverride} from '../../test-utils'
import apiUserContent from 'compiled/str/apiUserContent'
import Details from '../Details'

jest.mock('compiled/str/apiUserContent')
apiUserContent.convert = jest.fn(arg => `converted ${arg}`)

const override1 = {lid: '18', title: 'Section A', set: {name: 'Section A'}}
const override2 = {lid: '19', title: 'Section B', set: {name: 'Section B'}}

it('renders and converts', () => {
  const assignment = mockAssignment()
  const {getByText} = render(<Details assignment={assignment} />)
  getByText(`converted ${assignment.description}`)
  expect(getByText('Everyone')).toBeInTheDocument()
  expect(getByText('Due:', {exact: false})).toBeInTheDocument()
  expect(getByText('Available', {exact: false})).toBeInTheDocument()
})

it('renders an override', () => {
  const assignment = mockAssignment({
    assignmentOverrides: {
      nodes: [mockOverride()]
    }
  })
  const {getByText} = render(<Details assignment={assignment} />)
  expect(getByText('Section A')).toBeInTheDocument()
  expect(getByText('Everyone else')).toBeInTheDocument()
})

it('renders all the overrides', () => {
  const assignment = mockAssignment({
    dueAt: null,
    assignmentOverrides: {
      nodes: [mockOverride(override1), mockOverride(override2)]
    }
  })
  const {getByText, queryAllByText} = render(<Details assignment={assignment} />)
  expect(getByText('Section A')).toBeInTheDocument()
  expect(getByText('Section B')).toBeInTheDocument()
  expect(queryAllByText('Everyone', {exact: false})).toHaveLength(0)
})

it('renders the Add Override button if !readOnly', () => {
  const assignment = mockAssignment({
    dueAt: null,
    assignmentOverrides: {
      nodes: [mockOverride(override1), mockOverride(override2)]
    }
  })
  const {getByTestId} = render(<Details assignment={assignment} readOnly={false} />)

  expect(getByTestId('AddOverride')).toBeInTheDocument()
})

it('does notrender the Add Override button if readOnly', () => {
  const assignment = mockAssignment({
    dueAt: null,
    assignmentOverrides: {
      nodes: [mockOverride(override1), mockOverride(override2)]
    }
  })
  const {queryByTestId} = render(<Details assignment={assignment} readOnly />)

  expect(queryByTestId('AddOverride')).toBeNull()
})
